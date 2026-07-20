import { DOMParser, XMLSerializer } from '@xmldom/xmldom';
import type { Customer, Quotation } from '../types/domain';

const WORD_NS = 'http://schemas.openxmlformats.org/wordprocessingml/2006/main';
const XML_NS = 'http://www.w3.org/XML/1998/namespace';
const DOCX_MIME = 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';

const quoteDate = (value: string) => {
  const date = new Date(value);
  if (Number.isNaN(date.getTime())) return value;
  return new Intl.DateTimeFormat('en-GB', {
    timeZone: 'Asia/Kolkata', day: '2-digit', month: '2-digit', year: 'numeric',
  }).format(date).replaceAll('/', '-');
};

const customerAddress = (customer: Customer) => [
  customer.address, customer.villageCity, customer.taluka,
  customer.district ? `Dist. ${customer.district}` : '', customer.state, customer.pinCode,
].filter(Boolean).join(', ');

function childElements(parent: Element, localName: string) {
  return Array.from(parent.childNodes).filter((child) => child.nodeType === 1 && (child as Element).localName === localName) as Element[];
}

function setElementText(element: Element, value: string) {
  const nodes = Array.from(element.getElementsByTagNameNS(WORD_NS, 't'));
  if (!nodes.length) throw new Error('The official agreement template has an unexpected text structure.');
  nodes[0]!.textContent = value;
  nodes[0]!.setAttributeNS(XML_NS, 'xml:space', 'preserve');
  nodes.slice(1).forEach((node) => { node.textContent = ''; });
}

function removeCustomerSignature(cell: Element) {
  const removable = [
    ...Array.from(cell.getElementsByTagNameNS(WORD_NS, 'drawing')),
    ...Array.from(cell.getElementsByTagNameNS(WORD_NS, 'pict')),
  ];
  removable.forEach((node) => node.parentNode?.removeChild(node));
}

export function populateAgreementXml(xml: string, quotation: Quotation, customer: Customer) {
  const document = new DOMParser().parseFromString(xml, 'application/xml');
  if (document.getElementsByTagName('parsererror').length) throw new Error('The official agreement template could not be read.');
  const body = document.getElementsByTagNameNS(WORD_NS, 'body')[0];
  if (!body) throw new Error('The official agreement template has no document body.');
  const paragraphs = childElements(body, 'p');
  const table = childElements(body, 'tbl')[0];
  if (paragraphs.length < 7 || !table) throw new Error('The official agreement template layout has changed.');

  const date = quoteDate(quotation.createdAt);
  const address = customerAddress(customer);
  setElementText(paragraphs[3]!, `This agreement is executed on ${date} for design, supply, installation, commissioning and 5-year comprehensive maintenance of RTS project/system along with warranty under PM Surya Ghar: Muft Bijli Yojana`);
  setElementText(paragraphs[6]!, `${customer.fullName} having address at ${address}. (hereinafter referred to as first Party i.e. consumer).`);

  const rows = Array.from(table.getElementsByTagNameNS(WORD_NS, 'tr'));
  if (rows.length < 4) throw new Error('The official agreement signature table has changed.');
  const rowCells = rows.map((row) => Array.from(row.getElementsByTagNameNS(WORD_NS, 'tc')));
  if (!rowCells[0]?.[0] || !rowCells[1]?.[0] || !rowCells[3]?.[0] || !rowCells[3]?.[1]) {
    throw new Error('The official agreement signature fields could not be found.');
  }
  setElementText(rowCells[0][0], `Name: ${customer.fullName}`);
  removeCustomerSignature(rowCells[0][0]);
  setElementText(rowCells[1][0], `Address: ${address}`);
  setElementText(rowCells[3][0], `Date: ${date}`);
  setElementText(rowCells[3][1], `Date: ${date}`);

  const sectionProperties = Array.from(document.getElementsByTagNameNS(WORD_NS, 'sectPr'));
  const finalSection = sectionProperties.at(-1);
  if (finalSection) {
    let type = Array.from(finalSection.childNodes).find((child) => child.nodeType === 1 && (child as Element).localName === 'type') as Element | undefined;
    if (!type) {
      type = document.createElementNS(WORD_NS, 'w:type');
      finalSection.insertBefore(type, finalSection.firstChild);
    }
    type.setAttributeNS(WORD_NS, 'w:val', 'continuous');
  }
  return new XMLSerializer().serializeToString(document);
}

export async function createAgreementDocx(quotation: Quotation, customer: Customer) {
  const { default: JSZip } = await import('jszip');
  const response = await fetch('/templates/agreement-template.docx');
  if (!response.ok) throw new Error('The official agreement template is missing from this deployment.');
  const zip = await JSZip.loadAsync(await response.arrayBuffer());
  const documentFile = zip.file('word/document.xml');
  if (!documentFile) throw new Error('The official agreement template is invalid.');
  const populated = populateAgreementXml(await documentFile.async('string'), quotation, customer);
  zip.file('word/document.xml', populated);
  return zip.generateAsync({ type: 'blob', mimeType: DOCX_MIME, compression: 'DEFLATE' });
}

export function agreementFilename(quotation: Quotation) {
  return `${quotation.quoteNo.replace(/[^A-Za-z0-9_-]+/g, '-')}-agreement.docx`;
}

export const agreementMimeType = DOCX_MIME;
