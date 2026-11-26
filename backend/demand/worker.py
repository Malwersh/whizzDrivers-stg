"""Demand analytics only. Never writes orders, dispatch, drivers or financial tables."""
import os, json, hashlib
from datetime import datetime, timedelta, timezone
from zoneinfo import ZoneInfo
from collections import defaultdict
import boto3
from boto3.dynamodb.types import TypeDeserializer
from botocore.exceptions import ClientError

TZ = ZoneInfo('Asia/Baghdad')
VERSION = 1
DESERIALIZER = TypeDeserializer()


def local_date(at):
    return datetime.fromisoformat(at.replace('Z', '+00:00')).astimezone(TZ)


def forecast(events, coverage_start, now, excluded_days=None):
    """Recency weighted same weekday/hour, 8 weeks, complete observed days only.
    Missing weekdays are unknown, never zero; partial first/current days excluded.
    """
    excluded_days = excluded_days or set()
    today = now.astimezone(TZ).date()
    first = max(local_date(coverage_start).date() + timedelta(days=1), today - timedelta(days=56))
    counts = defaultdict(lambda: [0] * 24)
    for event in events:
        date = local_date(event['occurredAt'])
        if first <= date.date() < today:
            counts[date.date()][date.hour] += 1
    days = []
    for offset in range(7):
        target = today + timedelta(days=offset)
        samples = [first + timedelta(days=i) for i in range(max(0, (today-first).days))
                   if (first + timedelta(days=i)).weekday() == target.weekday() and str(first + timedelta(days=i)) not in excluded_days]
        count = sum(sum(counts[d]) for d in samples)
        enough = len(samples) >= 3 and count >= 20
        slots = []
        if enough:
            weights = [0.85 ** ((today-d).days // 7) for d in samples]
            slots = [sum(counts[d][h]*w for d, w in zip(samples, weights))/sum(weights) for h in range(24)]
        days.append({'date': str(target), 'sampleDays': len(samples), 'sampleOrders': count,
                     'confidence': 'HIGH' if len(samples) >= 6 and count >= 100 else 'MODERATE' if enough else 'INSUFFICIENT',
                     'values': slots})
    # One scale for the full forecast; no per-day rescaling that exaggerates quiet days.
    maximum = max([v for day in days for v in day['values']] or [0])
    for day in days:
        day['slots'] = [{'hour': h, 'score': round(value/maximum*100),
                         'level': 'LOW' if value/maximum < .34 else 'MEDIUM' if value/maximum < .67 else 'HIGH'}
                        for h, value in enumerate(day.pop('values'))] if maximum else []
    return days


def may_open(book, day, hour):
    """Any overlap with this hour, including previous-day overnight service.
    Unknown hours remain unknown/open; never invent a closure.
    """
    start = datetime.combine(day, datetime.min.time(), tzinfo=TZ) + timedelta(hours=hour)
    end = start + timedelta(hours=1)
    for date in (day - timedelta(days=1), day):
        row = book.get(date.strftime('%A'))
        if row is None:
            return True
        if row.get('isClosed') is True:
            continue
        opening, closing = row.get('opening'), row.get('closing')
        if opening in ('none','closed','') or closing in ('none','closed',''):
            continue
        try:
            oh, om = map(int, opening.split(':')); ch, cm = map(int, closing.split(':'))
            if not (0 <= oh < 24 and 0 <= ch <= 24 and 0 <= om < 60 and 0 <= cm < 60 and (ch < 24 or cm == 0)):
                return True
            left = datetime.combine(date, datetime.min.time(), tzinfo=TZ) + timedelta(hours=oh,minutes=om)
            right = datetime.combine(date, datetime.min.time(), tzinfo=TZ) + timedelta(hours=ch,minutes=cm)
            if right <= left:
                right += timedelta(days=1)
            if left < end and right > start:
                return True
        except (AttributeError, ValueError, TypeError):
            return True
    return False


def apply_hours(days, businesses, books):
    for day in days:
        for slot in day['slots']:
            if not any(may_open(books.get(b['businessId'], {}), datetime.fromisoformat(day['date']).date(), slot['hour']) for b in businesses):
                slot['score'], slot['level'] = 0, 'CLOSED'
    return days


class Worker:
    def __init__(self, db, config, now=None):
        self.db, self.c = db, config
        self.now = now or datetime.now(timezone.utc)
        self.table = db.Table(config['table'])
        self.cache = {}

    def get(self, table, key):
        cache_key = (table, json.dumps(key, sort_keys=True))
        if cache_key not in self.cache:
            self.cache[cache_key] = self.db.Table(table).get_item(Key=key, ConsistentRead=True).get('Item')
        return self.cache[cache_key]

    def ingest(self, job):
        if job.get('SK') != 'METADATA' or not job.get('orderId') or not job.get('restaurantId'):
            return 'IGNORED'
        at = job.get('createdAt')
        if not isinstance(at, str):
            raise ValueError('MISSING_DISPATCH_CREATION_TIME')
        date = local_date(at)
        if date < max(local_date(self.c['coverageStart']), self.now-timedelta(days=60)) or date > self.now + timedelta(minutes=5):
            return 'OUTSIDE_COVERAGE'
        key = {'pk': 'EVENT#'+self.c['dataset']+'#'+hashlib.sha256(job['orderId'].encode()).hexdigest(), 'sk': 'FIRST'}
        if self.table.get_item(Key=key, ConsistentRead=True).get('Item'):
            return 'DUPLICATE'
        order = self.get(self.c['orders'], {'PK': 'ORDER#'+job['orderId'], 'SK': 'META'})
        if not order:
            raise ValueError('ORDER_MISSING')
        if self.c['dataset'] == 'LIVE' and any(
                r.get('isTest') is True or r.get('isTestOrder') is True or r.get('testOrder') is True
                or r.get('environment') in ('staging', 'test') for r in [order, job]):
            return 'TEST_EXCLUDED'
        # Pinned pickup region preferred; branch lookup only at initial ingestion.
        region_id = job.get('restaurantRegionId') or order.get('pickupRegionId') or order.get('restaurantRegionId')
        if not region_id:
            branch = self.get(self.c['businesses'], {'businessId': job['restaurantId']})
            region_id = (branch or {}).get('regionId')
        region = self.get(self.c['regions'], {'regionId': region_id}) if region_id else None
        if not region or int(region.get('level', -1)) != 3 or not region.get('parent_id'):
            raise ValueError('PICKUP_REGION_UNAVAILABLE')
        item = {**key, 'kind': 'EVENT', 'dataset': self.c['dataset'], 'regionId': region_id,
                'districtId': region['parent_id'], 'occurredAt': at,
                'expiresAt': int((self.now + timedelta(days=120)).timestamp())}
        try:
            self.table.put_item(Item=item, ConditionExpression='attribute_not_exists(pk)')
            return 'RECORDED'
        except ClientError as error:
            if error.response['Error']['Code'] == 'ConditionalCheckFailedException':
                return 'DUPLICATE'
            raise

    def all_rows(self, table, **kwargs):
        """Never publish a partial scan. Pagination, deadline and row cap are hard stops."""
        rows, cursor = [], None
        import time
        started = time.monotonic()
        for _ in range(2000):
            result = self.db.Table(table).scan(ConsistentRead=True, **kwargs, **({'ExclusiveStartKey': cursor} if cursor else {}))
            rows.extend(result.get('Items', []))
            if len(rows) > 250000 or time.monotonic()-started > 180:
                raise ValueError('ANALYTICS_CAPACITY_REVIEW_REQUIRED')
            cursor = result.get('LastEvaluatedKey')
            if not cursor:
                return rows
        raise ValueError('INCOMPLETE_ANALYTICS_SCAN')

    def rebuild(self):
        health = self.table.get_item(Key={'pk':'HEALTH#'+self.c['dataset'],'sk':'LATEST'},ConsistentRead=True).get('Item')
        previous = local_date(health['completedAt'] if health else self.c['coverageStart'])
        if self.now - previous > timedelta(hours=2):
            day = previous.date()
            while day <= self.now.astimezone(TZ).date():
                self.table.put_item(Item={'pk':'GAP#'+self.c['dataset']+'#'+str(day),'sk':'DAY',
                    'kind':'GAP','dataset':self.c['dataset'],'date':str(day),
                    'expiresAt':int((self.now+timedelta(days=120)).timestamp())})
                day += timedelta(days=1)
        # Reconciliation catches stream delays and retries using the same permanent order key.
        jobs = self.all_rows(self.c['jobs'], FilterExpression='SK = :meta AND createdAt >= :start',
                             ExpressionAttributeValues={':meta': 'METADATA', ':start': max(self.c['coverageStart'], (self.now-timedelta(days=60)).isoformat())},
                             ProjectionExpression='orderId, SK, restaurantId, restaurantRegionId, createdAt, isTest, isTestOrder, testOrder, environment')
        for job in jobs:
            self.ingest(job)
        rows = self.all_rows(self.c['table'], FilterExpression='#k = :event OR #k = :gap',
                             ExpressionAttributeNames={'#k': 'kind'}, ExpressionAttributeValues={':event': 'EVENT', ':gap':'GAP'})
        regions = self.all_rows(self.c['regions'])
        businesses = self.all_rows(self.c['businesses'], ProjectionExpression='businessId, regionId, isActive, isDeleted, deletedAt, platformSuspended, ordersBlocked')
        hours = self.all_rows(self.c['hours'], ProjectionExpression='businessId, weekday, isClosed, opening, closing')
        books = defaultdict(dict)
        for row in hours:
            books[row['businessId']][row['weekday']] = row
        region_parents = {r['regionId']:r.get('parent_id') for r in regions}
        by_area = defaultdict(list)
        for branch in businesses:
            if branch.get('regionId') and branch.get('isActive') not in (False, 0) and not any(branch.get(k) for k in ('isDeleted','deletedAt','platformSuspended','ordersBlocked')):
                by_area[branch['regionId']].append(branch)
                if region_parents.get(branch['regionId']):
                    by_area[region_parents[branch['regionId']]].append(branch)
        excluded_days = {r['date'] for r in rows if r.get('kind')=='GAP' and r.get('dataset')==self.c['dataset']}
        groups = defaultdict(list)
        for row in rows:
            if row.get('dataset') == self.c['dataset'] and row.get('kind')=='EVENT':
                groups[row['regionId']].append(row)
                groups[row['districtId']].append(row)
        now = self.now.isoformat()
        for region in regions:
            if int(region.get('level', -1)) not in (2, 3):
                continue
            item = {'pk': 'FORECAST#'+self.c['dataset']+'#'+region['regionId'], 'sk': 'LATEST',
                    'schemaVersion': VERSION, 'dataset': self.c['dataset'], 'generatedAt': now,
                    'timezone': 'Asia/Baghdad', 'coverageStart': self.c['coverageStart'],
                    'days': apply_hours(forecast(groups[region['regionId']], self.c['coverageStart'], self.now, excluded_days), by_area[region['regionId']], books)}
            self.table.put_item(Item=item, ConditionExpression='attribute_not_exists(generatedAt) OR generatedAt <= :now',
                                ExpressionAttributeValues={':now': now})
        # Synthetic history is isolated from captured TEST/LIVE events and never enabled in LIVE.
        configured = self.c.get('simulationRegions') or [self.c.get('simulationRegion')]
        simulation_regions = list(dict.fromkeys(r for r in configured if r)) if self.c['dataset'] == 'TEST' else []
        simulated = False
        for simulation_region in simulation_regions:
            if not any(r['regionId'] == simulation_region and int(r.get('level', -1)) == 3 for r in regions):
                continue
            history = []
            today = self.now.astimezone(TZ).replace(hour=0, minute=0, second=0, microsecond=0)
            shape = [0,0,0,0,0,0,1,2,2,2,3,5,7,6,4,3,3,4,6,8,9,7,4,1]
            if simulation_region != self.c.get('simulationRegion'):
                seed = int(hashlib.sha256(simulation_region.encode()).hexdigest()[:8], 16)
                shape = [value + ((seed >> (hour % 16)) & 1) if value else 0 for hour, value in enumerate(shape)]
            for age in range(1,57):
                day = today - timedelta(days=age)
                for hour, base in enumerate(shape):
                    for count in range(base + (1 if day.weekday() in (3,4) and base else 0)):
                        history.append({'occurredAt':day.replace(hour=hour, minute=count).isoformat()})
            self.table.put_item(Item={'pk':'FORECAST#SIMULATION#'+simulation_region,'sk':'LATEST',
                'schemaVersion':VERSION,'dataset':'SIMULATION','generatedAt':now,'timezone':'Asia/Baghdad',
                'days':forecast(history,(today-timedelta(days=57)).isoformat(),self.now)})
            simulated = True
        if simulated:
            self.table.put_item(Item={'pk':'HEALTH#SIMULATION','sk':'LATEST','completedAt':now,'schemaVersion':VERSION})
        self.table.put_item(Item={'pk': 'HEALTH#'+self.c['dataset'], 'sk': 'LATEST', 'completedAt': now,
                                  'schemaVersion': VERSION})
        return {'success': True, 'regions': len(groups), 'events': sum(1 for r in rows if r.get('dataset') == self.c['dataset'] and r.get('kind')=='EVENT')}


def handler(event, context):
    config = {k: os.environ[v] for k, v in {'table': 'DEMAND_TABLE', 'jobs': 'DISPATCH_JOBS_TABLE',
              'orders': 'ORDERS_TABLE', 'businesses': 'BUSINESSES_TABLE', 'hours': 'WORKING_HOURS_TABLE', 'regions': 'REGIONS_TABLE',
              'dataset': 'DEMAND_DATASET', 'coverageStart': 'COVERAGE_START'}.items()}
    config['simulationRegion'] = os.environ.get('SIMULATION_REGION')
    config['simulationRegions'] = [r.strip() for r in os.environ.get('SIMULATION_REGIONS', '').split(',') if r.strip()]
    if config['simulationRegion'] and config['simulationRegion'] not in config['simulationRegions']:
        config['simulationRegions'].append(config['simulationRegion'])
    if config['dataset'] not in ('TEST', 'LIVE'):
        raise ValueError('INVALID_DATASET')
    worker = Worker(boto3.resource('dynamodb'), config)
    if 'Records' not in event:
        # Only EventBridge schedule or a controlled operational invoke; no API route.
        return worker.rebuild()
    failures = []
    for record in event['Records']:
        if record.get('eventName') not in ('INSERT', 'MODIFY'):
            continue
        try:
            job = {k: DESERIALIZER.deserialize(v) for k, v in record['dynamodb'].get('NewImage', {}).items()}
            worker.ingest(job)
        except Exception:
            failures.append({'itemIdentifier': record['dynamodb']['SequenceNumber']})
    return {'batchItemFailures': failures}
