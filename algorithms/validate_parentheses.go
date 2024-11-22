package main

import "fmt"

func isValid(s string) bool {
	stack := []rune{}

	if len(s) < 2 {
		return false
	}

	for _, char := range s {
		if char == '(' || char == '{' || char == '[' {
			stack = append(stack, char)
			// fmt.Println("Stack: ", string(stack))
			continue
		}

		if len(stack) == 0 {
			return false
		}

		lastChar := stack[len(stack)-1]
		stack = stack[:len(stack)-1]

		// fmt.Println("Char: ", char)
		// fmt.Println("Popped Char: ", lastChar)
		if char == ')' && lastChar != '(' {
			return false
		}

		if char == '}' && lastChar != '{' {
			return false
		}

		if char == ']' && lastChar != '[' {
			return false
		}
	}

	return len(stack) == 0
}

func main() {
	test1 := "()"
	test2 := "()[]{}"
	test3 := "(]"
	test4 := "([])"
	test5 := "(("
	test6 := "["
	test7 := "]"
	fmt.Println(isValid(test1))
	fmt.Println(isValid(test2))
	fmt.Println(isValid(test3))
	fmt.Println(isValid(test4))
	fmt.Println(isValid(test5))
	fmt.Println(isValid(test6))
	fmt.Println(isValid(test7))
}
