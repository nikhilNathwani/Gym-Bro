type IconProps = { className?: string };

const svgProps = {
  viewBox: "0 0 24 24",
  fill: "none",
  stroke: "currentColor",
  strokeWidth: 2.5,
  strokeLinecap: "round" as const,
  strokeLinejoin: "round" as const,
  "aria-hidden": true,
};

export function ArrowLeftIcon({ className }: IconProps) {
  return (
    <svg {...svgProps} className={className}>
      <path d="M19 12H5" />
      <path d="M11 18l-6-6 6-6" />
    </svg>
  );
}

export function ArrowUpIcon({ className }: IconProps) {
  return (
    <svg {...svgProps} className={className}>
      <path d="M12 19V5" />
      <path d="M6 11l6-6 6 6" />
    </svg>
  );
}

export function ArrowDownIcon({ className }: IconProps) {
  return (
    <svg {...svgProps} className={className}>
      <path d="M12 5v14" />
      <path d="M18 13l-6 6-6-6" />
    </svg>
  );
}

export function BackspaceIcon({ className }: IconProps) {
  return (
    <svg {...svgProps} strokeWidth={2} className={className}>
      <path d="M8 5h12a2 2 0 0 1 2 2v10a2 2 0 0 1-2 2H8l-6-7z" />
      <path d="M12 9l6 6" />
      <path d="M18 9l-6 6" />
    </svg>
  );
}
