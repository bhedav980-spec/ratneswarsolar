export function Brand({ compact = false }: { compact?: boolean }) {
  return (
    <div className={`brand ${compact ? 'brand--compact' : ''}`}>
      <img src={compact ? '/brand/ratneswar-logo.png' : '/brand/ratneswar-wordmark.png'} alt="Ratneswar Engineering" />
    </div>
  );
}
