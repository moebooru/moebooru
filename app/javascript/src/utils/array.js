/**
 * Return the values of list starting at idx and moving outwards.
 *
 * sort_array_by_distance([0,1,2,3,4,5,6,7,8,9], 5)
 * [5,4,6,3,7,2,8,1,9,0]
 */
export function sortArrayByDistance (list, idx) {
  const ret = [list[idx]];

  for (let distance = 1; ; ++distance) {
    const length = ret.length;

    if (idx - distance >= 0) {
      ret.push(list[idx - distance]);
    }

    if (idx + distance < list.length) {
      ret.push(list[idx + distance]);
    }

    if (length === ret.length) {
      break;
    }
  }

  return ret;
}
