// VialRGB effect IDs from Vial's RGB configurator. IDs are written unchanged.
const names = [
 'Off', 'Direct Control', 'Solid Color', 'Alphas and modifiers',
 'Gradient up and down', 'Gradient left and right', 'Breathing',
 'Saturation band', 'Brightness band', 'Pinwheel saturation band',
 'Pinwheel brightness band', 'Spiral saturation band', 'Spiral brightness band',
 'Cycle all colors', 'Cycle left to right', 'Cycle up and down',
 'Moving rainbow chevron', 'Cycle out and in', 'Dual cycle out and in',
 'Pinwheel cycle', 'Spiral cycle', 'Dual beacon', 'Rainbow beacon',
 'Rainbow pinwheels', 'Raindrops', 'Jellybean raindrops', 'Hue breathing',
 'Hue pendulum', 'Hue wave', 'Typing heatmap', 'Digital rain',
 'Simple reactive color', 'Reactive color', 'Wide reactive color',
 'Multiwide reactive color', 'Cross reactive color', 'Multicross reactive color',
 'Nexus reactive color', 'Multinexus reactive color', 'Splash', 'Multisplash',
 'Solid splash', 'Solid multisplash', 'Pixel rain', 'Pixel fractal',
];

export function lightingEffectName(id) { return names[id] ?? `Effect ${id}`; }

export function lightingHint(mode, saturation, brightness) {
 if (mode === 0) return 'The lights are off. Choose Solid Color to set one color for all keys.';
 if (mode === 1) return 'Direct Control needs a separate program to drive the lights. Choose Solid Color to set a color here.';
 if (mode === 2) {
  if (brightness === 0) return 'Brightness is at zero. Raise it to see the color on your keyboard.';
  if (saturation < 40) return 'Color intensity is low. Raise it to make the color easier to see on your keyboard.';
  return 'The keyboard lights change as you adjust them and save automatically.';
 }
 return 'Effects may use the color differently. Choose Solid Color to set one color for all keys.';
}
