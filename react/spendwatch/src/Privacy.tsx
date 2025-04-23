import { Card, CardHeader, CardTitle, ShieldIcon, CardDescription, CardContent } from "./components";

export const PrivacyPolicy: React.FC = () => {
    return (
        <Card className="w-full max-w-2xl mx-auto">
            <CardHeader>
                <CardTitle className="flex items-center">
                    <ShieldIcon className="mr-2 h-5 w-5" /> Privacy Policy
                </CardTitle>
                <CardDescription>Last updated: April 22, 2025</CardDescription>
            </CardHeader>
            <CardContent className="space-y-4">
                <h4 className="font-semibold">1. Introduction</h4>
                <p className="text-sm text-muted-foreground">
                    Welcome to SpendWatch. We are committed to protecting
                    your personal information and your right to privacy. If you
                    have any questions or concerns about this privacy notice, or
                    our practices with regards to your personal information,
                    please contact us.
                </p>
                <h4 className="font-semibold">2. Information We Collect</h4>
                <p className="text-sm text-muted-foreground">
                    We collect personal information that you voluntarily provide
                    to us when you register on the application, express an
                    interest in obtaining information about us or our products
                    and services, when you participate in activities on the
                    application or otherwise when you contact us.
                </p>
                <p className="text-sm text-muted-foreground">
                    The personal information that we collect depends on the
                    context of your interactions with us and the application,
                    the choices you make and the products and features you use.
                    The personal information we collect may include the
                    following: Email Address, Password (stored securely), and the data enter into the application.
                </p>
                <h4 className="font-semibold">
                    3. How We Use Your Information
                </h4>
                <p className="text-sm text-muted-foreground">
                    We use personal information collected via our application
                    for a variety of business purposes described below. We
                    process your personal information for these purposes in
                    reliance on our legitimate business interests, in order to
                    enter into or perform a contract with you, with your
                    consent, and/or for compliance with our legal obligations.
                </p>
                <h4 className="font-semibold">4. Sharing</h4>
                <p className="text-sm text-muted-foreground">
                    We do not share your information with any 3rd parties. The information 
                    you enter is kept secure and accessible to you and shared only with anyone you 
                    invite to share your information with in the use of the application.
                </p>
                <h4 className="font-semibold">5. Contact Us</h4>
                <p className="text-sm text-muted-foreground">
                    If you have questions or comments about this notice, you may
                    email us at privacy@spend-watch.com.
                </p>
            </CardContent>
        </Card>
    );
};