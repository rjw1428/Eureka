# Given two non-negative integers num1 and num2 represented as strings, return the product of num1 and num2, also represented as a string.

# Example 1
#   Input: num1 = "2", num2 = "3"
#   Output: "6"

# Example 2
#   Input: num1 = "123", num2 = "456"
#   Output: "56088"


def multiply(num1: str, num2: str) -> str:
    a=b=0
    offset = 48
    for i in num1:
        c1 = ord(i)-offset
        a = a*10+c1
    for j in num2:
        c2 = ord(j)-offset
        b = b*10+c2

    return str(a*b)

print(multiply("123456789", "987654321"))