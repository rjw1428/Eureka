import React from "react";
import { PrivacyPolicy } from "./Privacy";
import { Route, Routes } from "react-router-dom";
import { Home } from "./Home";
import { DeleteAccount } from "./DeleteAccount";

const App: React.FC = () => {
    return (
        <div className="min-h-screen bg-background text-foreground flex flex-col items-center p-4 md:p-8 font-sans">
            <h1 className="text-3xl font-bold mb-8">Spend Watch</h1>
            <nav className="mb-8 flex space-x-4" aria-label="Main Navigation">
            </nav>

            <main className="w-full flex-grow flex justify-center">
              <Routes>
                <Route path="/" element={<Home />} />
                <Route path="/privacy" element={<PrivacyPolicy />} />
                <Route path="/deleteaccount" element={<DeleteAccount />} />
              </Routes>
                
            </main>

            <footer className="mt-8 text-center text-xs text-muted-foreground">
                SpendWatch | © {new Date().getFullYear()} RWSS
            </footer>
        </div>
    );
};

export default App;
