/*
 * Add two numbers as linked lists

Given two non-empty linked lists representing a two non-negative integers where the digits are stored in reverse order, add them

Example 1:
  Input: l1 = [2,4,3], l2 = [5,6,4]
  Output: [7,0,8]
  Explanation: 342 + 465 = 807

Example 2:
  Input: l1 = [0] l2 = [0]
  Output: [0]
  
Example 3:
  Input: l1 = [9,9,9,9,9,9,9], l2 = [9,9,9,9]
  Output: [8,9,9,9,0,0,0,1]
  Explanation: 9999999 + 9999 = 10009998


Notes: The number of nodes in the linked list may be from 1 -> 100. No leading 0's
 */

class ListNode {
    val: number;
    next: ListNode | null;
    constructor(val?: number, next?: ListNode | null) {
        this.val = val === undefined ? 0 : val;
        this.next = next === undefined ? null : next;
    }

    toString() {
        let output = this.val.toString();
        let current = this as ListNode
        while (current.next) {
            output += current.next.val.toString();
            current = current.next
        }
        return output;
    }
}

function reverse(head: ListNode) {
    let prev: ListNode | null = null;
    let curr: ListNode | null = head;
    let next: ListNode | null;

    while (curr !== null) {
        next = curr.next;
        curr.next = prev;
        prev = curr;
        curr = next;
    }
    return prev;
}

function addTwoNumbers(
    l1: ListNode | null,
    l2: ListNode | null
): ListNode | null  {
    let res: ListNode | null = null
    let curr: ListNode | null = null
    let carry = 0;

    while (l1 !== null || l2 !== null || carry !== 0) {
        let sum = carry;

        // If l1 linked list is not empty, add it to sum
        if (l1 !== null) {
            sum += l1.val;
            l1 = l1.next;
        }

        // If l2 linked list is not empty, add it to sum
        if (l2 !== null) {
            sum += l2.val;
            l2 = l2.next;
        }

        // Create a new node with sum % 10 as its value
        let newNode = new ListNode(sum % 10);

        // Store the carry for the next nodes
        carry = +(sum >= 10)

        // If this is the first node, then make this node
        // as the head of the resultant linked list
        if (res === null) {
            res = newNode;
            curr = newNode;
        } 
        else {
            // Append new node to resultant linked list
            // and move to the next node
            curr!.next = newNode;
            curr = curr!.next;
        }
    }

    return res
}

const a1 = new ListNode(2, new ListNode(4, new ListNode(3)));
const a2 = new ListNode(5, new ListNode(6, new ListNode(4)));
console.log(a1.toString());
console.log(a2.toString())
const aResult = addTwoNumbers(a1, a2)
console.log(aResult?.toString(), aResult?.toString() == '708')

const b1 = new ListNode(0);
const b2 = new ListNode(0);
console.log(b1.toString());
console.log(b2.toString())
const bResult = addTwoNumbers(b1, b2)
console.log(bResult?.toString(), bResult?.toString() == '0')

const c1 = new ListNode(9, new ListNode(9, new ListNode(9, new ListNode(9, new ListNode(9, new ListNode(9, new ListNode(9)))))));
const c2 = new ListNode(9, new ListNode(9, new ListNode(9, new ListNode(9))));
console.log(c1.toString());
console.log(c2.toString())
const cResult = addTwoNumbers(c1, c2)
console.log(cResult?.toString(), cResult?.toString() == '89990001')
