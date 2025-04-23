// --- Type Definitions ---

import React, { ForwardedRef } from "react";
import { BaseComponentProps, ButtonProps, IconProps, InputProps, LabelProps } from "./models";



export const Card: React.FC<BaseComponentProps> = ({ className = "", children }) => (
    <div
        className={`rounded-xl border bg-card text-card-foreground shadow ${className}`}
    >
        {children}
    </div>
);

export const CardHeader: React.FC<BaseComponentProps> = ({
    className = "",
    children,
}) => (
    <div className={`flex flex-col space-y-1.5 p-6 ${className}`}>
        {children}
    </div>
);

export const CardTitle: React.FC<BaseComponentProps> = ({
    className = "",
    children,
}) => (
    <h3 className={`font-semibold leading-none tracking-tight ${className}`}>
        {children}
    </h3>
);

export const CardDescription: React.FC<BaseComponentProps> = ({
    className = "",
    children,
}) => (
    <p className={`text-sm text-muted-foreground ${className}`}>{children}</p>
);

export const CardContent: React.FC<BaseComponentProps> = ({
    className = "",
    children,
}) => <div className={`p-6 pt-0 ${className}`}>{children}</div>;

export const CardFooter: React.FC<BaseComponentProps> = ({
    className = "",
    children,
}) => (
    <div className={`flex items-center p-6 pt-0 ${className}`}>{children}</div>
);

export const Input = React.forwardRef<HTMLInputElement, InputProps>(
    (
        { className = "", type, ...props },
        ref: ForwardedRef<HTMLInputElement>
    ) => (
        <input
            type={type}
            className={`flex h-10 w-full rounded-md border border-input bg-transparent px-3 py-2 text-sm ring-offset-background file:border-0 file:bg-transparent file:text-sm file:font-medium placeholder:text-muted-foreground focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-ring focus-visible:ring-offset-2 disabled:cursor-not-allowed disabled:opacity-50 ${className}`}
            ref={ref}
            {...props}
        />
    )
);

export const Button = React.forwardRef<HTMLButtonElement, ButtonProps>(
    (
        { className = "", variant = "default", size = "default", ...props },
        ref: ForwardedRef<HTMLButtonElement>
    ) => {
        const baseStyle =
            "inline-flex items-center justify-center rounded-md text-sm font-medium ring-offset-background transition-colors focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-ring focus-visible:ring-offset-2 disabled:pointer-events-none disabled:opacity-50 cursor-pointer";
        // Type assertion for variant and size keys
        const variants: Record<NonNullable<ButtonProps["variant"]>, string> = {
            default: "bg-primary text-primary-foreground hover:bg-primary/90",
            destructive:
                "bg-destructive text-destructive-foreground hover:bg-destructive/90",
            outline:
                "border border-input bg-background hover:bg-accent hover:text-accent-foreground",
            secondary:
                "bg-secondary text-secondary-foreground hover:bg-secondary/80",
            ghost: "hover:bg-accent hover:text-accent-foreground",
            link: "text-primary underline-offset-4 hover:underline",
        };
        const sizes: Record<NonNullable<ButtonProps["size"]>, string> = {
            default: "h-10 px-4 py-2",
            sm: "h-9 rounded-md px-3",
            lg: "h-11 rounded-md px-8",
            icon: "h-10 w-10",
        };
        return (
            <button
                className={`${baseStyle} ${variants[variant]} ${sizes[size]} ${className}`}
                ref={ref}
                {...props}
            />
        );
    }
);

export const Label = React.forwardRef<HTMLLabelElement, LabelProps>(
    ({ className = "", ...props }, ref: ForwardedRef<HTMLLabelElement>) => (
        <label
            ref={ref}
            className={`text-sm font-medium leading-none peer-disabled:cursor-not-allowed peer-disabled:opacity-70 ${className}`}
            {...props}
        />
    )
);

export const ShieldIcon: React.FC<IconProps> = (props) => (
    <svg
        {...props}
        xmlns="http://www.w3.org/2000/svg"
        width="24"
        height="24"
        viewBox="0 0 24 24"
        fill="none"
        stroke="currentColor"
        strokeWidth="2"
        strokeLinecap="round"
        strokeLinejoin="round"
    >
        <path d="M12 22s8-4 8-10V5l-8-3-8 3v7c0 6 8 10 8 10z"></path>
    </svg>
);

export const Trash2Icon: React.FC<IconProps> = (props) => (
    <svg
        {...props}
        xmlns="http://www.w3.org/2000/svg"
        width="24"
        height="24"
        viewBox="0 0 24 24"
        fill="none"
        stroke="currentColor"
        strokeWidth="2"
        strokeLinecap="round"
        strokeLinejoin="round"
    >
        <path d="M3 6h18"></path>
        <path d="M19 6v14a2 2 0 0 1-2 2H7a2 2 0 0 1-2-2V6m3 0V4a2 2 0 0 1 2-2h4a2 2 0 0 1 2 2v2"></path>
        <line x1="10" y1="11" x2="10" y2="17"></line>
        <line x1="14" y1="11" x2="14" y2="17"></line>
    </svg>
);

export const AlertCircleIcon: React.FC<IconProps> = (props) => (
    <svg
        {...props}
        xmlns="http://www.w3.org/2000/svg"
        width="24"
        height="24"
        viewBox="0 0 24 24"
        fill="none"
        stroke="currentColor"
        strokeWidth="2"
        strokeLinecap="round"
        strokeLinejoin="round"
    >
        <circle cx="12" cy="12" r="10"></circle>
        <line x1="12" y1="8" x2="12" y2="12"></line>
        <line x1="12" y1="16" x2="12.01" y2="16"></line>
    </svg>
);

export const CheckCircleIcon: React.FC<IconProps> = (props) => (
    <svg
        {...props}
        xmlns="http://www.w3.org/2000/svg"
        width="24"
        height="24"
        viewBox="0 0 24 24"
        fill="none"
        stroke="currentColor"
        strokeWidth="2"
        strokeLinecap="round"
        strokeLinejoin="round"
    >
        <path d="M22 11.08V12a10 10 0 1 1-5.93-9.14"></path>
        <polyline points="22 4 12 14.01 9 11.01"></polyline>
    </svg>
);