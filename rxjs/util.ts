export function createArray(size: number) {
    return new Array(size).fill(0).map((_, i) => i)
}