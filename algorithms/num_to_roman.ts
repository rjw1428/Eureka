/**
 
Seven different symbols represent Roman numerals with the following values:

Symbol	Value
I	1
V	5
X	10
L	50
C	100
D	500
M	1000
Roman numerals are formed by appending the conversions of decimal place values from highest to lowest. Converting a decimal place value into a Roman numeral has the following rules:

If the value does not start with 4 or 9, select the symbol of the maximal value that can be subtracted from the input, append that symbol to the result, subtract its value, and convert the remainder to a Roman numeral.
If the value starts with 4 or 9 use the subtractive form representing one symbol subtracted from the following symbol, for example, 4 is 1 (I) less than 5 (V): IV and 9 is 1 (I) less than 10 (X): IX. Only the following subtractive forms are used: 4 (IV), 9 (IX), 40 (XL), 90 (XC), 400 (CD) and 900 (CM).
Only powers of 10 (I, X, C, M) can be appended consecutively at most 3 times to represent multiples of 10. You cannot append 5 (V), 50 (L), or 500 (D) multiple times. If you need to append a symbol 4 times use the subtractive form.


Example 1:

Input: num = 3749

Output: "MMMDCCXLIX"

Explanation:

3000 = MMM as 1000 (M) + 1000 (M) + 1000 (M)
 700 = DCC as 500 (D) + 100 (C) + 100 (C)
  40 = XL as 10 (X) less of 50 (L)
   9 = IX as 1 (I) less of 10 (X)
Note: 49 is not 1 (I) less of 50 (L) because the conversion is based on decimal places
Example 2:

Input: num = 58

Output: "LVIII"

Explanation:

50 = L
 8 = VIII
Example 3:

Input: num = 1994

Output: "MCMXCIV"

Explanation:

1000 = M
 900 = CM
  90 = XC
   4 = IV


INPUT CONSTRAINT: 1 <= num <= 3999
 */


function intToRoman(num: number): string {
    let numeral = '';
    if (num >= 1000) {
        const m = Math.floor(num / 1000);
        numeral += 'M'.repeat(m);
        num -= m * 1000;
    }

    if (num >= 900) {
        numeral += 'CM';
        num -= 900;
    }

    if (num >= 500) {
        const d = Math.floor(num / 500);
        numeral += 'D'.repeat(d);
        num -= 500 * d;
    }

    if (num >= 400) {
        numeral += 'CD';
        num -= 400;
    }

    if (num >= 100) {
        const c = Math.floor(num / 100);
        numeral += 'C'.repeat(c);
        num -= 100 * c;
    }

    if (num >= 90) {
        numeral += 'XC';
        num -= 90;
    }

    if (num >= 50) {
        const l = Math.floor(num / 50);
        numeral += 'L'.repeat(l);
        num -= 50 * l;
    }

    if (num >= 40) {
        numeral += 'XL';
        num -= 40;
    }

    if (num >= 10) {
        const x = Math.floor(num / 10);
        numeral += 'X'.repeat(x);
        num -= 10 * x;
    }

    if (num >= 9) {
        numeral += 'IX';
        num -= 9;
    } 

    if (num >= 5) {
        const v = Math.floor(num / 5);
        numeral += 'V'.repeat(v);
        num -= 5 * v;
    }

    if (num >= 4) {
        numeral += 'IV';
        num -= 4;
    }

    if (num > 0) {
        numeral += 'I'.repeat(num);
    }

    return numeral;
};

console.log(intToRoman(58) == "LVIII");
console.log(intToRoman(1994) == "MCMXCIV");
console.log(intToRoman(1000) == "M");  
console.log(intToRoman(3749) == "MMMDCCXLIX");

function intToRoman2(num: number): string {
    const ones = ["", "I", "II", "III", "IV", "V", "VI", "VII", "VIII", "IX"];
    const tens = ["", "X", "XX", "XXX", "XL", "L", "LX", "LXX", "LXXX", "XC"];
    const hund = ["", "C", "CC", "CCC", "CD", "D", "DC", "DCC", "DCCC", "CM"];
    const thou = ["", "M", "MM", "MMM"];
    const th = Math.floor(num/1000);
    const h = Math.floor((num%1000)/100)
    const t = Math.floor((num%100)/10)
    const o = num%10
    console.log(th, h , t, o)
    return thou[th] + hund[h] + tens[t] + ones[o];
}

// console.log(intToRoman2(58) == "LVIII");
// console.log(intToRoman2(1994) == "MCMXCIV");
// console.log(intToRoman2(1000) == "M");  
console.log(intToRoman2(3749) == "MMMDCCXLIX");