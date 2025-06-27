#include <iostream>
#include <algorithm>

// AVL Tree Node
struct Node {
    int key;
    Node* left;
    Node* right;
    int height;
    Node(int k) : key(k), left(nullptr), right(nullptr), height(1) {}
};

class AVLTree {
public:
    AVLTree() : root(nullptr) {}

    void insert(int key) {
        root = insert(root, key);
    }

    void remove(int key) {
        root = remove(root, key);
    }

    void inorder() const {
        inorder(root);
        std::cout << std::endl;
    }

private:
    Node* root;

    int height(Node* n) const {
        return n ? n->height : 0;
    }

    int balanceFactor(Node* n) const {
        return n ? height(n->left) - height(n->right) : 0;
    }

    void updateHeight(Node* n) {
        n->height = 1 + std::max(height(n->left), height(n->right));
    }

    Node* rotateRight(Node* y) {
        Node* x = y->left;
        Node* T2 = x->right;
        x->right = y;
        y->left = T2;
        updateHeight(y);
        updateHeight(x);
        return x;
    }

    Node* rotateLeft(Node* x) {
        Node* y = x->right;
        Node* T2 = y->left;
        y->left = x;
        x->right = T2;
        updateHeight(x);
        updateHeight(y);
        return y;
    }

    Node* insert(Node* node, int key) {
        if (!node) return new Node(key);
        if (key < node->key)
            node->left = insert(node->left, key);
        else if (key > node->key)
            node->right = insert(node->right, key);
        else
            return node; // No duplicates

        updateHeight(node);

        int balance = balanceFactor(node);

        // Left Left
        if (balance > 1 && key < node->left->key)
            return rotateRight(node);

        // Right Right
        if (balance < -1 && key > node->right->key)
            return rotateLeft(node);

        // Left Right
        if (balance > 1 && key > node->left->key) {
            node->left = rotateLeft(node->left);
            return rotateRight(node);
        }

        // Right Left
        if (balance < -1 && key < node->right->key) {
            node->right = rotateRight(node->right);
            return rotateLeft(node);
        }

        return node;
    }

    Node* minValueNode(Node* node) {
        Node* current = node;
        while (current->left)
            current = current->left;
        return current;
    }

    Node* remove(Node* root, int key) {
        if (!root) return root;

        if (key < root->key)
            root->left = remove(root->left, key);
        else if (key > root->key)
            root->right = remove(root->right, key);
        else {
            if (!root->left || !root->right) {
                Node* temp = root->left ? root->left : root->right;
                if (!temp) {
                    temp = root;
                    root = nullptr;
                } else
                    *root = *temp;
                delete temp;
            } else {
                Node* temp = minValueNode(root->right);
                root->key = temp->key;
                root->right = remove(root->right, temp->key);
            }
        }

        if (!root) return root;

        updateHeight(root);

        int balance = balanceFactor(root);

        // Left Left
        if (balance > 1 && balanceFactor(root->left) >= 0)
            return rotateRight(root);

        // Left Right
        if (balance > 1 && balanceFactor(root->left) < 0) {
            root->left = rotateLeft(root->left);
            return rotateRight(root);
        }

        // Right Right
        if (balance < -1 && balanceFactor(root->right) <= 0)
            return rotateLeft(root);

        // Right Left
        if (balance < -1 && balanceFactor(root->right) > 0) {
            root->right = rotateRight(root->right);
            return rotateLeft(root);
        }

        return root;
    }

    void inorder(Node* node) const {
        if (!node) return;
        inorder(node->left);
        std::cout << node->key << " ";
        inorder(node->right);
    }
};

// Example usage
int main() {
    AVLTree tree;
    tree.insert(10);
    tree.insert(20);
    tree.insert(30);
    tree.insert(40);
    tree.insert(50);
    tree.insert(25);

    std::cout << "Inorder traversal after insertions: ";
    tree.inorder();

    tree.remove(40);
    std::cout << "Inorder traversal after removing 40: ";
    tree.inorder();

    tree.remove(25);
    std::cout << "Inorder traversal after removing 25: ";
    tree.inorder();

    return 0;
}