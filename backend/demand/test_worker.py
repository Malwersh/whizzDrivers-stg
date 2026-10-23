import unittest
from datetime import datetime, timedelta, timezone
from unittest.mock import MagicMock
from worker import forecast, Worker, may_open

class DemandTests(unittest.TestCase):
    def test_weekday_weighting_and_isolation(self):
        now=datetime(2026,10,23,10,tzinfo=timezone.utc)
        events=[]
        for week in range(1,9):
            for i in range(10):
                events.append({'occurredAt':(now-timedelta(weeks=week)).isoformat()})
        days=forecast(events,'2026-08-20T00:00:00+00:00',now)
        self.assertEqual(len(days),7)
        self.assertEqual(days[0]['confidence'],'MODERATE')
        self.assertEqual(days[0]['slots'][13]['score'],100) # UTC10 = Baghdad13
        self.assertEqual(days[1]['confidence'],'INSUFFICIENT')
        self.assertEqual(days[1]['slots'],[])
    def test_outage_days_are_unknown_not_zero_samples(self):
        now=datetime(2026,10,23,10,tzinfo=timezone.utc)
        events=[{'occurredAt':(now-timedelta(weeks=w)).isoformat()} for w in range(1,4) for _ in range(20)]
        days=forecast(events,'2026-10-01T00:00:00Z',now,{'2026-10-09'})
        self.assertEqual(days[0]['confidence'],'INSUFFICIENT')
        self.assertLess(days[0]['sampleDays'],3)
    def test_partial_days_are_not_training_data(self):
        now=datetime(2026,10,23,10,tzinfo=timezone.utc)
        e=[{'occurredAt':now.isoformat()}]*100
        self.assertTrue(all(d['confidence']=='INSUFFICIENT' for d in forecast(e,now.isoformat(),now)))
    def test_ingestion_permanent_dedupe_and_no_source_writes(self):
        db=MagicMock();table=db.Table.return_value;table.get_item.return_value={}
        c={'table':'analytics','dataset':'TEST','coverageStart':'2026-10-01T00:00:00+00:00','orders':'orders','regions':'regions','businesses':'branches'}
        w=Worker(db,c,datetime(2026,10,23,tzinfo=timezone.utc))
        w.get=lambda t,k: {'pickupRegionId':'a'} if t=='orders' else {'regionId':'a','level':3,'parent_id':'district'}
        job={'SK':'METADATA','orderId':'one','restaurantId':'branch','createdAt':'2026-10-22T10:00:00Z'}
        self.assertEqual(w.ingest(job),'RECORDED')
        item=table.put_item.call_args.kwargs['Item']
        self.assertEqual(item['regionId'],'a');self.assertNotIn('orderId',item)
        table.get_item.return_value={'Item':item}
        self.assertEqual(w.ingest({**job,'restaurantRegionId':'other'}),'DUPLICATE')
        self.assertEqual(table.put_item.call_count,1)
        self.assertEqual(set(c.args[0] for c in db.Table.call_args_list),{'analytics'})
    def test_live_excludes_test(self):
        db=MagicMock();db.Table.return_value.get_item.return_value={}
        w=Worker(db,{'table':'analytics','dataset':'LIVE','orders':'orders','coverageStart':'2026-10-01T00:00:00Z'},datetime(2026,10,23,tzinfo=timezone.utc))
        w.get=lambda t,k:{'isTestOrder':True}
        self.assertEqual(w.ingest({'SK':'METADATA','orderId':'one','restaurantId':'b','createdAt':'2026-10-22T10:00:00Z'}),'TEST_EXCLUDED')
        db.Table.return_value.put_item.assert_not_called()
    def test_hours_overnight_partial_hour_closed_and_unknown(self):
        from datetime import date
        day=date(2026,10,23)
        book={'Thursday':{'opening':'22:00','closing':'02:00'},'Friday':{'opening':'12:30','closing':'23:00'}}
        self.assertTrue(may_open(book,day,1))
        self.assertTrue(may_open(book,day,12))
        self.assertFalse(may_open(book,day,3))
        self.assertTrue(may_open({},day,3))
        book['Friday']={'isClosed':True}
        self.assertFalse(may_open(book,day,12))
    def test_simulation_regions_and_live_isolation(self):
        for dataset, regions_config, expected in (
            ('TEST', {'simulationRegions':['a','b','a','district','missing'], 'simulationRegion':'a'}, {'a','b'}),
            ('TEST', {'simulationRegion':'a'}, {'a'}),
            ('LIVE', {'simulationRegions':['a','b'], 'simulationRegion':'a'}, set()),
        ):
            with self.subTest(dataset=dataset, config=regions_config):
                db=MagicMock(); table=db.Table.return_value; table.get_item.return_value={}
                now=datetime(2026,10,23,10,tzinfo=timezone.utc)
                config={'table':'analytics','dataset':dataset,'jobs':'jobs','regions':'regions',
                        'businesses':'branches','hours':'hours','coverageStart':now.isoformat(),**regions_config}
                w=Worker(db,config,now)
                w.all_rows=lambda name,**kwargs: ([{'regionId':'a','level':3},{'regionId':'b','level':3},
                    {'regionId':'district','level':2}] if name=='regions' else [])
                w.rebuild()
                items=[call.kwargs['Item'] for call in table.put_item.call_args_list]
                simulated=[x for x in items if x['pk'].startswith('FORECAST#SIMULATION#')]
                self.assertEqual({x['pk'].split('#')[-1] for x in simulated},expected)
                for item in simulated:
                    self.assertEqual(len(item['days']),7)
                    self.assertTrue(all(len(day['slots'])==24 for day in item['days']))
                    self.assertEqual(item['generatedAt'],now.isoformat())
                self.assertEqual(sum(x['pk']=='HEALTH#SIMULATION' for x in items),bool(expected))
                self.assertTrue(all(day['confidence']=='INSUFFICIENT' for x in items
                    if x['pk'].startswith('FORECAST#'+dataset+'#') for day in x['days']))
                self.assertEqual({call.args[0] for call in db.Table.call_args_list},{'analytics'})

    def test_page_error_cannot_return_partial_data(self):
        db=MagicMock();db.Table.return_value.scan.side_effect=[{'Items':[1],'LastEvaluatedKey':{'pk':'next'}},RuntimeError('down')]
        with self.assertRaises(RuntimeError):Worker(db,{'table':'a'}).all_rows('a')

if __name__=='__main__':unittest.main()
