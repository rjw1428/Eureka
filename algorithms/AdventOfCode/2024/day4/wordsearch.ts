/*
--- Day 4: Ceres Search ---
"Looks like the Chief's not here. Next!" One of The Historians pulls out a device and pushes the only button on it. After a brief flash, you recognize the interior of the Ceres monitoring station!

As the search for the Chief continues, a small Elf who lives on the station tugs on your shirt; she'd like to know if you could help her with her word search (your puzzle input). She only has to find one word: XMAS.

This word search allows words to be horizontal, vertical, diagonal, written backwards, or even overlapping other words. It's a little unusual, though, as you don't merely need to find one instance of XMAS - you need to find all of them. Here are a few ways XMAS might appear, where irrelevant characters have been replaced with .:


..X...
.SAMX.
.A..A.
XMAS.S
.X....
The actual word search will be full of letters instead. For example:

MMMSXXMASM
MSAMXMSMSA
AMXSXMAAMM
MSAMASMSMX
XMASAMXAMM
XXAMMXXAMA
SMSMSASXSS
SAXAMASAAA
MAMMMXMMMM
MXMXAXMASX
In this word search, XMAS occurs a total of 18 times; here's the same word search again, but where letters not involved in any XMAS have been replaced with .:

....XXMAS.
.SAMXMS...
...S..A...
..A.A.MS.X
XMASAMX.MM
X.....XA.A
S.S.S.S.SS
.A.A.A.A.A
..M.M.M.MM
.X.X.XMASX
Take a look at the little Elf's word search. How many times does XMAS appear?
2507
*/


import { count, countDiagonalUpperRight, transpose, flip } from './matrix'
import fs from "node:fs";

const partOneTarget = "XMAS"
fs.readFile("input.txt", "utf8", (err, data) => {
    if (err) {
        console.error(err);
        return;
    }

    // console.log(wordSearchCount(data.split('\r\n'), partOneTarget))
    console.log(xCount(data.split('\r\n')))

});

function wordSearchCount(matrix: string[], target: string) {
    let sum = 0

    // Search Rows
    for (let i = 0; i < matrix.length; i++) {
        sum += count(matrix[i], target)
        sum += count(matrix[i].split('').reverse().join(''), target)
    }

    // Search Cols
    for (let i = 0; i < matrix.length; i++) {
        sum += count(matrix.map(row => row[i]).join(''), target)
        sum += count(matrix.map(row => row[i]).reverse().join(''), target)
    }
    console.log(sum)
    // Search Diagonals
    const upperRight = countDiagonalUpperRight(matrix, target)
    const lowerRight = countDiagonalUpperRight(transpose(matrix), target, 1)
    const upperLeft = countDiagonalUpperRight(flip(matrix), target)
    const lowerLeft = countDiagonalUpperRight(transpose(flip(matrix)), target, 1)

    console.log(upperRight, lowerRight, upperLeft, lowerLeft)
    sum += upperRight + lowerRight + upperLeft + lowerLeft

    return sum
}


/* 
--- Part Two ---
The Elf looks quizzically at you. Did you misunderstand the assignment?

Looking for the instructions, you flip over the word search to find that this isn't actually an XMAS puzzle; it's an X-MAS puzzle in which you're supposed to find two MAS in the shape of an X. One way to achieve that is like this:

M.S
.A.
M.S
Irrelevant characters have again been replaced with . in the above diagram. Within the X, each MAS can be written forwards or backwards.

Here's the same example from before, but this time all of the X-MASes have been kept instead:

.M.S......
..A..MSMS.
.M.S.MAA..
..A.ASMSM.
.M.S.M....
..........
S.S.S.S.S.
.A.A.A.A..
M.M.M.M.M.
..........
In this example, an X-MAS appears 9 times.

Flip the word search from the instructions back over to the word search side and try again. How many times does an X-MAS appear?
1969
*/

function xCount(matrix: string[]) {
    let count = 0
    for (let i = 1; i<matrix.length - 1; i++) {
        for (let j=1; j<matrix[i].length - 1; j++) {
            if (matrix[i][j] === 'A') {
                let mCount = 0
                let sCount = 0
                const upperLeft = matrix[i-1][j-1]
                const upperRight = matrix[i-1][j+1]
                const lowerLeft = matrix[i+1][j-1]
                const lowerRight = matrix[i+1][j+1]
                
                /*
                * Avoid
                MXS
                XAX
                SXM
                */
                if (lowerRight === upperLeft || upperRight === lowerLeft) {
                    continue
                }
                
                
                // Check upper left
                if (upperLeft === 'M') {
                    mCount++
                }
                if (upperLeft === 'S') {
                    sCount++
                }
                
                // Check upper right
                if (upperRight === 'M') {
                    mCount++
                }
                if (upperRight === 'S') {
                    sCount++
                }

                // Check lower Left
                if (lowerLeft === 'M') {
                    mCount++
                }
                if (lowerLeft === 'S') {
                    sCount++
                }

                // Check lower right
                if (lowerRight === 'M') {
                    mCount++
                }
                if (lowerRight === 'S') {
                    sCount++
                }

                if (mCount === 2 && sCount === 2) {
                    count++
                }
            }
        }
    }
    return count
}