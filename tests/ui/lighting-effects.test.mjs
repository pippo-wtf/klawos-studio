import test from 'node:test';
import assert from 'node:assert/strict';
import {lightingEffectName,lightingHint} from '../../ui/lighting-effects.mjs';

test('VialRGB effect names identify the color modes',()=>{
 assert.equal(lightingEffectName(2),'Solid Color');
 assert.equal(lightingEffectName(3),'Alphas and modifiers');
 assert.equal(lightingEffectName(44),'Pixel fractal');
});

test('lighting guidance explains when a color change will be visible',()=>{
 assert.match(lightingHint(2,18,71),/Color intensity is low/);
 assert.match(lightingHint(2,255,0),/Brightness is at zero/);
 assert.match(lightingHint(3,255,200),/Choose Solid Color/);
 assert.match(lightingHint(1,255,200),/separate program/);
});
