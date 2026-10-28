"""Execute the exact production Swift filename pattern, not a mocked Dart bridge."""
from pathlib import Path
import subprocess,json
root=Path(__file__).resolve().parents[1]
s=(root/'frontend/ios/Runner/AppDelegate.swift').read_text()
line=next(l for l in s.splitlines()if 'static let offerCueFilePattern ='in l)
literal=line.split('=',1)[1].strip()
assert 'file.range(of:Self.offerCueFilePattern,options:.regularExpression)'in s
valid=['driver_original.wav','driver_offer.wav','online_chime.wav','soft_chime.wav','merchant_bell.wav','first_nitification_sound.wav','custom_'+'a'*64+'.wav']
invalid=['../driver_original.wav','driver_original.WAV','driver_original\\xwav','unknown.wav','custom_bad.wav','custom_'+'g'*64+'.wav','driver_original.wav/extra']
code='import Foundation\nlet pattern='+literal+'\n'
for value in valid:code+='precondition('+json.dumps(value)+'.range(of:pattern,options:.regularExpression) != nil, "valid sound rejected")\n'
for value in invalid:code+='precondition('+json.dumps(value)+'.range(of:pattern,options:.regularExpression) == nil, "invalid path accepted")\n'
custom=next(l for l in s.splitlines()if 'static let customSoundFilePattern ='in l).split('=',1)[1].strip()
assert 'name.range(of:Self.customSoundFilePattern,options:.regularExpression)'in s
code+='let customPattern='+custom+'\n'
code+='precondition('+json.dumps('custom_'+'a'*64+'.wav')+'.range(of:customPattern,options:.regularExpression) != nil)\n'
for name in ['driver_original.wav','../custom_'+'a'*64+'.wav','custom_bad.wav']:
 code+='precondition('+json.dumps(name)+'.range(of:customPattern,options:.regularExpression) == nil)\n'
code+='print("PASS exact native Swift validators: 14 playback and 4 custom-install cases")\n'
p=Path('/private/tmp/offer-sound-295-validator.swift');p.write_text(code)
subprocess.run(['xcrun','swift','-module-cache-path','/private/tmp/offer-sound-295-swift-cache',str(p)],check=True)
