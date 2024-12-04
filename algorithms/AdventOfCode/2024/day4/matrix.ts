export const flip = (matrix: string[]) => {
    return matrix.map(row => row.split('').reverse().join(''))
}

export const transpose = (matrix: string[]) => {
    let result: string[] = []
    for (let i = 0; i<matrix.length; i++) {
        let row = ''
        for (let j = 0; j<matrix.length; j++) {
            row += matrix[j][i]
        }
        result.push(row)
    }
    return result
}

export const count = (row: string, target: string) => {
    const symbol = '@'
    return row.replaceAll(target, symbol).split('').filter(x => x === symbol).length
}

export const countDiagonalUpperRight = (matrix: string[], target: string, initialOffset = 0) => {
    let row: string[] = []
    let matches = 0
    for (let offset = initialOffset; offset < matrix.length - target.length + 1; offset++) {
        for (let i = offset; i<matrix.length; i++) {
            row.push(matrix[i-offset][i])
        }
        matches += count(row.join(''), target)
        matches += count(row.reverse().join(''), target)
        row = []
    }
    return matches
}