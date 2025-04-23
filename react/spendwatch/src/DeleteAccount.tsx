import { ChangeEvent, FormEvent, useCallback, useState } from "react";
import { Credentials, DeleteAccountResponse, MessageState } from "./models";
import { AlertCircleIcon, Button, Card, CardContent, CardDescription, CardFooter, CardHeader, CardTitle, CheckCircleIcon, Input, Label, Trash2Icon } from "./components";
import { getAuth, signInWithEmailAndPassword, deleteUser } from "firebase/auth";
import { initializeApp } from "firebase/app";

export const DeleteAccount: React.FC = () => {
    const firebaseConfig = {
        apiKey: "AIzaSyDdYYnz3jV4UF9OOo3Bj_uYkD03W6vIkdw",
        authDomain: "taskr-1428.firebaseapp.com",
        projectId: "taskr-1428",
        storageBucket: "taskr-1428.firebasestorage.app",
        messagingSenderId: "1070956843093",
        appId: "1:1070956843093:web:d9a0b18158d15cae6604dc"
    };
    const app = initializeApp(firebaseConfig);
    const auth = getAuth(app);

    // State variables with explicit types
    const [email, setEmail] = useState<string>("");
    const [password, setPassword] = useState<string>("");
    const [isLoading, setIsLoading] = useState<boolean>(false);
    const [message, setMessage] = useState<MessageState>({
        type: "",
        text: "",
    });

    const callDeleteAccountFunction = async (
        credentials: Credentials
    ): Promise<DeleteAccountResponse> => {

        try {
            const resp = await signInWithEmailAndPassword(auth, credentials.email, credentials.password)
            await deleteUser(resp.user)
            return {
                success: true,
                message:
                    "Account deletion process initiated successfully.",
            }
        } catch (e) {
            console.log(e)
            return {
                success: false,
                message:
                    "Failed to delete account. Please check credentials or try again later.",
            }
        }
    };

    const handleDeleteAccount = useCallback(
        async (event: FormEvent<HTMLFormElement>) => {
            event.preventDefault(); // Prevent default form submission
            setMessage({ type: "", text: "" }); // Clear previous messages
            setIsLoading(true);

            if (!email || !password) {
                setMessage({
                    type: "error",
                    text: "Please enter both email and password.",
                });
                setIsLoading(false);
                return;
            }

            const result = await callDeleteAccountFunction({ email, password });

            if (result.success) {
                setMessage({ type: "success", text: result.message });
                setEmail('');
                setPassword('');
            } else {
                setMessage({ type: "error", text: result.message });
            }

            setIsLoading(false);
        },
        // eslint-disable-next-line react-hooks/exhaustive-deps
        [email, password]
    );

    const handleEmailChange = (event: ChangeEvent<HTMLInputElement>) => {
        setEmail(event.target.value);
    };

    const handlePasswordChange = (event: ChangeEvent<HTMLInputElement>) => {
        setPassword(event.target.value);
    };

    return (
        <Card className="w-full max-w-md mx-auto">
            <CardHeader>
                <CardTitle className="flex items-center">
                    <Trash2Icon className="mr-2 h-5 w-5 text-destructive" />{" "}
                    Delete Account
                </CardTitle>
                <CardDescription>
                    Enter your credentials to permanently delete your account.
                    This action cannot be undone.
                </CardDescription>
            </CardHeader>
            <CardContent>
                <form onSubmit={handleDeleteAccount} className="space-y-4">
                    <div className="space-y-2">
                        <Label htmlFor="email">Email</Label>
                        <Input
                            id="email"
                            type="email"
                            placeholder="you@example.com"
                            value={email}
                            onChange={handleEmailChange} // Use typed handler
                            required
                            disabled={isLoading}
                            aria-label="Email for account deletion"
                        />
                    </div>
                    <div className="space-y-2">
                        <Label htmlFor="password">Password</Label>
                        <Input
                            id="password"
                            type="password"
                            placeholder="••••••••"
                            value={password}
                            onChange={handlePasswordChange} // Use typed handler
                            required
                            disabled={isLoading}
                            aria-label="Password for account deletion"
                        />
                    </div>
                    {/* Message Area */}
                    {message.text && (
                        <div
                            role="alert"
                            className={`flex items-center p-3 rounded-md text-sm ${
                                message.type === "error"
                                    ? "bg-destructive/10 text-destructive"
                                    : "bg-green-100 text-green-700"
                            }`}
                        >
                            {message.type === "error" ? (
                                <AlertCircleIcon
                                    className="w-4 h-4 mr-2"
                                    aria-hidden="true"
                                />
                            ) : (
                                <CheckCircleIcon
                                    className="w-4 h-4 mr-2"
                                    aria-hidden="true"
                                />
                            )}
                            {message.text}
                        </div>
                    )}
                    <Button
                        type="submit"
                        className="w-full"
                        variant="outline"
                        disabled={isLoading}
                    >
                        {isLoading ? "Deleting..." : "Delete My Account"}
                    </Button>
                </form>
            </CardContent>
            <CardFooter>
                <p className="text-xs text-muted-foreground text-center w-full">
                    Warning: Account deletion is permanent and cannot be
                    reversed. All your data associated with this account will be
                    lost.
                </p>
            </CardFooter>
        </Card>
    );
};