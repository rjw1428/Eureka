// Compile: 
// g++ invert_binary_tree.cpp -o output/invert_binary_tree
#include <iostream>

struct Node {
    int data;
    Node *left, *right;
    Node(int x) {
        data = x;
        left = nullptr;
        right = nullptr;
    }
};

Node* mirror(Node* root) {
    if (root == nullptr)
        return nullptr;
    
    // Invert the left and right subtree
    Node* left = mirror(root->left);
    Node* right = mirror(root->right);

    // Swap the left and right subtree
    root->left = right;
    root->right = left;

    return root;
}

void inOrder(Node* root) {
    if (root == nullptr)
        return;
    inOrder(root->left);
    std::cout << root->data << " ";
    inOrder(root->right);
}

int main() {
    // Input Tree:
    //       1
    //      / \
    //     2   3
    //    / \
    //   4   5
    Node* root = new Node(1);
    root->left = new Node(2);
    root->right = new Node(3);
    root->left->left = new Node(4);
    root->left->right = new Node(5);

    root = mirror(root);

    // Mirror Tree:
    //       1
    //      / \
    //     3   2
    //        / \
    //       5   4
    inOrder(root);

    return 0;
}