/*
 * Search for Index
Given a sorted array of distinct integers and a target value, return the index if the target is found. 
If not, return the index where it would be if it were inserted in order.

You must write an algorithm with O(log n) runtime complexity.

Example 1:
    Input: nums = [1,3,5,6], target = 5
    Output: 2

Example 2:
    Input: nums = [1,3,5,6], target = 2
    Output: 1

Example 3:
    Input: nums = [1,3,5,6], target = 7
    Output: 4
 */



function searchInsert(nums: number[], target: number): number {
    return searchRec(nums, target, 0);
};

function searchRec(nums: number[], target: number, count: number): number {
    if (nums.length == 0) {
        return 0
    }

    if (nums.length == 1) {
        return nums[0] < target
            ? count + 1
            : count
    }

    const half = Math.floor(nums.length / 2)
    if (nums[half] > target) {
        return searchRec(nums.slice(0, half), target, count)
    }
    if (nums[half] < target) {
        return searchRec(nums.slice(half), target, count + half)
    }
    return half + count
}


function searchInsert2(nums: number[], target: number): number {
    let index = 0;
    nums.find((n, i) => {
        if(n >= target){
            index = i
            return index
        }
        index++
    })
    return index
}


console.log(searchInsert2([1,3,5,6], 2))