import { Card, CardHeader, CardTitle, CardDescription, CardContent } from "./components";

export const Home: React.FC = () => {
    return (
        <Card className="w-full max-w-2xl mx-auto flex flex-col justify-between">
            <CardHeader>
                <CardTitle className="flex items-center">
                    Bring the friction back into spending mony
                </CardTitle>
                <CardDescription>
                    Download now on the google play store and take control of your families financial future
                </CardDescription>
            </CardHeader>
            <CardContent className="flex justify-center basis-full">
                <a href="" ><img src="GetItOnGooglePlay_Badge_Web_color_English.png"></img></a>
            </CardContent>
        </Card>
    )
};