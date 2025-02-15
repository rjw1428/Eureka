import { useQuery } from "react-query";
import "./App.css";
import { useState } from "react";

type JokeResponse = {
    icon_url: string;
    id: string;
    value: string;
};

export default function App() {
    const [isLoading, setLoading] = useState(true);
    const { error, data, refetch } = useQuery("jokeData", async () => {
        const resp = await getJoke();
        return resp;
    });

    async function getJoke(): Promise<JokeResponse> {
        setLoading(true);
        console.log("Getting joke");
        // generate random error
        const shouldError = Math.floor(Math.random() * 5) === 4;
        console.log({ shouldError });

        await new Promise((resolve) => setTimeout(resolve, 3000));
        const response = await fetch(
            `https://api.chucknorris.io/jokes/random${shouldError ? "z" : ""}`
        );
        setLoading(false);
        if (!response.ok) {
            console.log(response);
            throw new Error(`An error has occurred: ${response.status}`);
        }
        return response.json() as unknown as JokeResponse;
    }
    if (isLoading) {
        return <h1>Loading...</h1>;
    }

    if (error) {
        return (
            <>
                <h1>{`Nukin Futz ${error}`}</h1>
                <button onClick={() => refetch()}>Try Again</button>
            </>
        );
    }
    return (
        <>
            <h1>{data?.value}</h1>
            <button onClick={() => refetch()}>Hit Me Again!</button>
        </>
    );
}
