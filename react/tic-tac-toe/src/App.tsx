import { useState } from "react";
import "./App.css";

function Square({
    value,
    onClick,
}: {
    value: string | null;
    onClick: () => void;
}) {
    return (
        <button className="square" onClick={onClick}>
            {value}
        </button>
    );
}

function calculateWinner(squares: Array<string | null>): string | null {
    const lines = [
        [0, 1, 2],
        [3, 4, 5],
        [6, 7, 8],
        [0, 3, 6],
        [1, 4, 7],
        [2, 5, 8],
        [0, 4, 8],
        [2, 4, 6],
    ];
    const winner = lines.find(
        ([a, b, c]) =>
            squares[a] && squares[a] === squares[b] && squares[a] === squares[c]
    );
    return winner ? squares[winner[0]] : null;
}

function Board({
    xTurn,
    squares,
    onTurn,
}: {
    xTurn: boolean;
    squares: Array<string | null>;
    onTurn: (nextBoard: Array<string | null>) => void;
}) {
    const winner = calculateWinner(squares);
    const status = winner
        ? `${winner}'s have won!!!`
        : `Turn: ${xTurn ? "X" : "O"}`;

    function handleClick(index: number) {
        // If square already has a value, do nothing so that the user can pick a new square
        if (squares[index]) {
            return;
        }

        squares[index] = xTurn ? "X" : "O";
        onTurn([...squares]);
    }

    return (
        <>
            <div className="status">{status}</div>
            <div className="board-row">
                <Square value={squares[0]} onClick={() => handleClick(0)} />
                <Square value={squares[1]} onClick={() => handleClick(1)} />
                <Square value={squares[2]} onClick={() => handleClick(2)} />
            </div>
            <div className="board-row">
                <Square value={squares[3]} onClick={() => handleClick(3)} />
                <Square value={squares[4]} onClick={() => handleClick(4)} />
                <Square value={squares[5]} onClick={() => handleClick(5)} />
            </div>
            <div className="board-row">
                <Square value={squares[6]} onClick={() => handleClick(6)} />
                <Square value={squares[7]} onClick={() => handleClick(7)} />
                <Square value={squares[8]} onClick={() => handleClick(8)} />
            </div>
        </>
    );
}

export default function Game() {
    const [history, setHistory] = useState([Array(9).fill(null)]);
    const [currentMove, setCurrentMove] = useState(0);
    const current = history[currentMove];
    const isXTurn = currentMove % 2 === 0
    
    function handleTurn(nextBoard: Array<string | null>) {
        const nextHistory = history.slice(0, currentMove + 1).concat([nextBoard]) 
        setHistory(nextHistory);
        setCurrentMove(nextHistory.length -1)
    }

    function jumpTo(moveNum: number) {
        console.log(`jump to ${moveNum}`);
        setCurrentMove(moveNum)
    }

    const moves = history.map((_squares, move) => {
        const description = `Go to ${
            move === 0 ? "start of game" : `move number ${move}`
        }`;
        return (
            <li key={move}>
                <button onClick={() => jumpTo(move)}>{description}</button>
            </li>
        );
    });

    return (
        <div className="game">
            <div className="game-board">
                <Board xTurn={isXTurn} squares={current} onTurn={handleTurn} />
            </div>
            <div className="game-info">
                {moves.length > 1 && <ol>{moves.slice(0, moves.length - 1)}</ol>}
            </div>
        </div>
    );
}
