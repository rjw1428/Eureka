/*
* Longest Substring Without Repeating Characters:

Given a string, find the lenght of the longest substring without repeating characters

Example 1:
  Input: s = "abcabcbb"
  Output: 3
  Explanation: The answer is "abc", with the length of 3.

Example 2:
  Input: s = "bbbbb"
  Output: 1
  Explanation: The answer is "b", with the length of 1.

Example 3:
  Input: s = "pwwkew"
  Output: 3
  Explanation: The answer is "wke", with the length of 3.
  Notice that the answer must be a substring, "pwke" is a subsequence and not a substring.

 */

function lengthOfLongestSubstring(s: string): number {
    let max = 0;
    if (s.length <= 1) {
        return s.length;
    }

    for (let i = 0; i < s.length; i++) {
        for (let j = i + 1; j < s.length; j++) {
            const acc = s.slice(i, j);
            const compareChar = s.at(j)!;
            if (acc.includes(compareChar)) {
                const delta = acc.length;
                max = delta > max ? delta : max;
                break;
            }

            if (j == s.length - 1) {
                const delta = acc.length + 1;
                max = delta > max ? delta : max;
                return max;
            }
        }
    }
    return max;
}

function lengthOfLongestSubstring2(s: string): number {
    let max = 0;
    if (s.length <= 1) {
        return s.length;
    }

    const arr: string[] = [];
    for (let i = 0; i < s.length; i++) {
        const char = s.at(i)!;
        const index = arr.indexOf(char);
        if (index >= 0) {
            arr.splice(0, index + 1);
            arr.push(char);
            continue;
        }
        arr.push(char);
        max = max > arr.length ? max : arr.length;
    }
    return max;
}

console.log(lengthOfLongestSubstring("pwwkew"));
