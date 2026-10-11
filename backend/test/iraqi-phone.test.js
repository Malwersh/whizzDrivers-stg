const { test } = require('node:test');
const assert = require('node:assert/strict');
const { normalizeIraqiPhone } = require('../phone-auth/iraqi-phone');
test('normalizes supported Iraqi formats and Arabic digits', () => {
  for (const number of ['07701234567', '7701234567', '+9647701234567', '9647701234567', '009647701234567', '٠٧٧٠١٢٣٤٥٦٧', '۰۷۷۰۱۲۳۴۵۶۷', '+964 (770) 123-4567']) {
    assert.equal(normalizeIraqiPhone(number), '+9647701234567');
  }
});
test('rejects foreign, malformed and non-mobile numbers', () => {
  for (const number of ['+15551234567', '+971501234567', '+9641770123456', '0770123456', '077012345678', '+96407701234567', 'abc07701234567', '++9647701234567', '', null, 7701234567]) {
    assert.throws(() => normalizeIraqiPhone(number));
  }
});
