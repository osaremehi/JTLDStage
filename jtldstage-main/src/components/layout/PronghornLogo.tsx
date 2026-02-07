import jtldstageLogo from "@/assets/pronghorn-logo.jpeg";
import { cn } from "@/lib/utils";

export function JTLDstageLogo({ className = "h-8 w-8" }: { className?: string }) {
  return (
    <img 
      src={jtldstageLogo} 
      alt="JTLDstage Logo" 
      className={cn("rounded-lg", className)}
    />
  );
}
