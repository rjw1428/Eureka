// Interface for basic component props that include className and children
export interface BaseComponentProps {
    className?: string;
    children?: React.ReactNode;
}

// Interface for Input props, extending standard HTML input attributes
export interface InputProps extends React.InputHTMLAttributes<HTMLInputElement> {
    className?: string;
}

// Interface for Button props, extending standard HTML button attributes
export interface ButtonProps extends React.ButtonHTMLAttributes<HTMLButtonElement> {
    className?: string;
    variant?:
        | "default"
        | "destructive"
        | "outline"
        | "secondary"
        | "ghost"
        | "link";
    size?: "default" | "sm" | "lg" | "icon";
}

// Interface for Label props, extending standard HTML label attributes
export interface LabelProps extends React.LabelHTMLAttributes<HTMLLabelElement> {
    className?: string;
}

// Interface for SVG Icon props
export type IconProps = React.SVGProps<SVGSVGElement>;

// Interface for the message state in DeleteAccount
export interface MessageState {
    type: "error" | "success" | "";
    text: string;
}

// Interface for credentials passed to the delete function
export interface Credentials {
    email: string;
    password: string; 
}

// Interface for the response from the delete function simulation
export interface DeleteAccountResponse {
    success: boolean;
    message: string;
}
