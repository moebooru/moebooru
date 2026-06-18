import { clamp } from 'src/utils/math';

export default class ClipRange {
  constructor (min, max) {
    if (min > max) {
      throw new Error('paramError (min is larger than max)');
    }
    this.min = min;
    this.max = max;
  }

  clip (x) {
    return clamp(x, this.min, this.max);
  }
}
