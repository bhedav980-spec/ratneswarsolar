const options = (filename: string) => ({
  margin: [0, 0, 0, 0] as [number, number, number, number],
  filename,
  image: { type: 'png' as const, quality: 1 },
  html2canvas: { scale: 3, useCORS: true, backgroundColor: '#ffffff', scrollX: 0, scrollY: 0, letterRendering: true },
  jsPDF: { unit: 'mm', format: 'a4', orientation: 'portrait' as const, compress: true },
  pagebreak: { mode: ['css', 'legacy'], avoid: ['tr', '.keep-together'] },
});

function getDocument(elementId: string) {
  const element = document.getElementById(elementId);
  if (!element) throw new Error('Printable document is not available.');
  return element;
}

async function renderFixedPages(element: HTMLElement) {
  const pages = Array.from(element.querySelectorAll<HTMLElement>('[data-pdf-page]'));
  if (!pages.length) return null;

  const [{ default: html2canvas }, { jsPDF }] = await Promise.all([
    import('html2canvas'),
    import('jspdf'),
  ]);

  if (document.fonts?.ready) await document.fonts.ready;
  const pdf = new jsPDF({ unit: 'mm', format: 'a4', orientation: 'portrait', compress: true });

  for (const [index, page] of pages.entries()) {
    const canvas = await html2canvas(page, {
      scale: 3,
      useCORS: true,
      allowTaint: false,
      backgroundColor: '#ffffff',
      logging: false,
      scrollX: 0,
      scrollY: -window.scrollY,
      width: page.clientWidth,
      height: page.clientHeight,
      windowWidth: page.clientWidth,
      windowHeight: page.clientHeight,
    });
    if (index > 0) pdf.addPage('a4', 'portrait');
    pdf.addImage(canvas.toDataURL('image/png'), 'PNG', 0, 0, 210, 297, undefined, 'FAST');
  }

  return pdf;
}

export async function downloadCleanPdf(elementId: string, filename: string) {
  const element = getDocument(elementId);
  const fixedPdf = await renderFixedPages(element);
  if (fixedPdf) {
    fixedPdf.save(filename);
    return;
  }
  const { default: html2pdf } = await import('html2pdf.js');
  await html2pdf().set(options(filename)).from(element).save();
}

export async function openCleanPdf(elementId: string, filename: string) {
  const popup = window.open('', '_blank');
  if (popup) popup.document.write('<title>Preparing printable PDF...</title><p style="font:16px sans-serif;padding:24px">Preparing clean A4 PDF...</p>');
  const element = getDocument(elementId);
  const fixedPdf = await renderFixedPages(element);
  let blob: Blob;
  if (fixedPdf) {
    blob = fixedPdf.output('blob');
  } else {
    const { default: html2pdf } = await import('html2pdf.js');
    const worker = html2pdf().set(options(filename)).from(element).toPdf();
    blob = await worker.outputPdf('blob');
  }
  const url = URL.createObjectURL(blob);
  if (popup) popup.location.href = url;
  else if (fixedPdf) fixedPdf.save(filename);
  else {
    const { default: html2pdf } = await import('html2pdf.js');
    await html2pdf().set(options(filename)).from(element).save();
  }
  window.setTimeout(() => URL.revokeObjectURL(url), 120_000);
}
