const {test}=require('node:test');const assert=require('node:assert/strict');const {registrationOptions,validateRegistration}=require('../registration-regions');
const rows=[{regionId:'iq',name_ar:'العراق',level:0,effective_is_active:1},{regionId:'g',level:1,parent_id:'iq',name_ar:'محافظة',effective_is_active:1},{regionId:'d',level:2,parent_id:'g',name_ar:'قضاء',effective_is_active:1},{regionId:'r',level:3,parent_id:'d',name_ar:'منطقة',effective_is_active:1},{regionId:'closed',level:3,parent_id:'d',effective_is_active:0},{regionId:'disabledDelivery',level:3,parent_id:'d',effective_is_active:1,effective_config:{delivery:false}}];
test('options use real hierarchy and expose only open delivery areas',()=>{
 const options=registrationOptions(rows);assert.deepEqual(options.regions.map(r=>r.regionId),['r']);assert.equal(options.governorates.length,1);
 const profile=validateRegistration({vehicleType:'car',governorate_id:'g',work_region_id:'r'},options);assert.equal(profile.country_id,'iq');assert.equal(profile.parent_district_id,'d');assert.equal(profile.home_region_id,'r');
 assert.throws(()=>validateRegistration({vehicleType:'car',governorate_id:'other',work_region_id:'r'},options));assert.throws(()=>validateRegistration({vehicleType:'car',governorate_id:'g',work_region_id:'closed'},options));
});

test('vehicle selection is required and restricted to supported delivery vehicles',()=>{const options=registrationOptions(rows);for(const vehicleType of [undefined,'unknown','truck'])assert.throws(()=>validateRegistration({vehicleType,governorate_id:'g',work_region_id:'r'},options));for(const vehicleType of ['car','motorcycle'])assert.equal(validateRegistration({vehicleType,governorate_id:'g',work_region_id:'r'},options).vehicleType,vehicleType);});
