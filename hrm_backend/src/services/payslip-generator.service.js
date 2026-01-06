const PDFDocument = require('pdfkit');
const StreamBuffers = require('stream-buffers');
const fs = require('fs');
const path = require('path');

/**
 * Helper: Draw a cell with specific borders
 * UPDATED: Calculates exact vertical center based on text height
 */
function drawCell(doc, x, y, width, height, text, options = {}) {
  const {
    isBold = false,
    align = 'center',
    fontSize = 9,
    borders = { top: true, right: true, bottom: true, left: true },
    valign = 'middle' // Default is middle
  } = options;

  // 1. Draw borders
  doc.lineWidth(1); // Ensure line width is consistent
  if (borders.top) doc.moveTo(x, y).lineTo(x + width, y).stroke();
  if (borders.right) doc.moveTo(x + width, y).lineTo(x + width, y + height).stroke();
  if (borders.bottom) doc.moveTo(x, y + height).lineTo(x + width, y + height).stroke();
  if (borders.left) doc.moveTo(x, y).lineTo(x, y + height).stroke();

  // 2. Set Font Settings FIRST (Needed to measure height)
  const fontName = isBold ? 'Roboto-Bold' : 'Roboto';
  doc.font(fontName).fontSize(fontSize);

  // 3. Calculate Vertical Position
  let textY = y + 5; // Default padding for top alignment

  if (valign === 'middle') {
    // Measure exact height of the text block
    const textHeight = doc.heightOfString(text || '', {
      width: width - 8,
      align: align
    });
    // Formula: StartY + (BoxHeight - TextHeight) / 2
    textY = y + (height - textHeight) / 2;
  }

  // 4. Draw Text
  doc.text(text || '', x + 4, textY, {
    width: width - 8,
    align: align
  });
}

/**
 * Helper: Draw merged cell
 */
function drawMergedCell(doc, x, y, width, height, text, options = {}) {
  drawCell(doc, x, y, width, height, text, options);
}

/**
 * EXACT LAYOUT GENERATOR
 */
function generateExactLayout(doc, payslipRequest, config) {
  const cf = payslipRequest.calculatedFields || {};
  const deductions = payslipRequest.deductions || {};
  const details = payslipRequest.payslipDetails || {};
  const employee = payslipRequest.employee || {};

  // === CONFIGURATION ===
  const pageMargin = 30;
  const fullWidth = 535;
  const startX = pageMargin;

  // 4-Column Grid Definition
  const col1Width = fullWidth * 0.28;  // Earnings Description
  const col2Width = fullWidth * 0.22;  // Earnings Amount
  const col3Width = fullWidth * 0.28;  // Deductions Description
  const col4Width = fullWidth * 0.22;  // Deductions Amount

  let y = 30;
  doc.lineWidth(1);

  // === A. HEADER SECTION ===
  const headerHeight = 130;
  const logoWidth = 130;    // Configured for bigger logo
  const companyInfoWidth = fullWidth - logoWidth;

  doc.rect(startX, y, fullWidth, headerHeight).stroke();

  // --- 1. DRAW LOGO ---
  if (config.hasLogo && config.logoPath && fs.existsSync(config.logoPath)) {
    try {
      doc.image(config.logoPath, startX + 15, y + 10, {
        fit: [logoWidth - 20, headerHeight - 20],
        align: 'center',
        valign: 'center'
      });
    } catch (err) {
      console.warn("⚠️ [PAYSLIP-GEN] Logo image error:", err.message);
    }
  }

  // --- 2. DRAW TEXT ---
  const textX = startX + logoWidth;
  const cleanAddress = config.address.replace(/\n/g, ' ');

  // Company Name
  doc.font('Roboto-Bold').fontSize(20)
    .text(config.companyName, textX, y + 28, { width: companyInfoWidth, align: 'center' });

  // Address
  doc.font('Roboto').fontSize(8)
    .text(cleanAddress, textX, y + 55, { width: companyInfoWidth, align: 'center' });

  // Payslip Title
  doc.font('Roboto-Bold').fontSize(12)
    .text(`Payslip for the month of ${payslipRequest.startMonth} ${payslipRequest.startYear}`,
      textX, y + 90, { width: companyInfoWidth, align: 'center' });

  y += headerHeight;

  // === B. EMPLOYEE PAY SUMMARY (Vertical Layout) ===
  const summaryRowHeight = 16;
  const leftHalfWidth = col1Width + col2Width;
  // const rightHalfWidth = col3Width + col4Width; // Unused, but calculation implies split

  // Header: "Employee Pay Summary" (Auto-centered by updated drawMergedCell)
  drawMergedCell(doc, startX, y, fullWidth, summaryRowHeight, 'Employee Pay Summary', { isBold: true, fontSize: 10 });
  y += summaryRowHeight;

  const employeeLines = [
    { left: `Employee Name :`, leftVal: employee.name || '', right: 'PAN:', rightVal: details.pan || '' },
    { left: `Emp Code :`, leftVal: employee.employeeId || '', right: 'Bank Name:', rightVal: details.bankName || '' },
    { left: `Designation :`, leftVal: employee.jobTitle || '', right: 'Account Number:', rightVal: details.accountNumber || '' },
    { left: `Joining Date :`, leftVal: employee.joinDate ? new Date(employee.joinDate).toLocaleDateString('en-IN', { day: '2-digit', month: '2-digit', year: 'numeric' }) : 'N/A', right: 'PF Number:', rightVal: details.pfNumber || '' },
    { left: `Pay Period :`, leftVal: `${payslipRequest.startMonth} ${payslipRequest.startYear}`, right: 'UAN No:', rightVal: details.uan || '' },
    { left: '', leftVal: '', right: 'Paid Days:', rightVal: details.paidDays || '30' },
    { left: '', leftVal: '', right: 'LOP Days:', rightVal: details.lopDays || '0' }
  ];

  const summaryBlockHeight = employeeLines.length * summaryRowHeight;

  // Draw Outer Box and Middle Divider
  doc.rect(startX, y, fullWidth, summaryBlockHeight).stroke();
  doc.moveTo(startX + leftHalfWidth, y).lineTo(startX + leftHalfWidth, y + summaryBlockHeight).stroke();

  let tempY = y;
  for (let i = 0; i < employeeLines.length; i++) {
    const line = employeeLines[i];
    // Note: We use manual doc.text here for the list items to control specific left/right spacing
    // We center them vertically using manual math (tempY + 3) which looks good for this font size
    if (line.left) doc.font('Roboto').fontSize(9).text(`${line.left} ${line.leftVal}`, startX + 4, tempY + 4);
    if (line.right) doc.font('Roboto').fontSize(9).text(`${line.right} ${line.rightVal}`, startX + leftHalfWidth + 4, tempY + 4);
    tempY += summaryRowHeight;
  }

  y += summaryBlockHeight;

  // === C. FINANCIAL TABLE HEADERS ===
  const tableRowHeight = 20;

  // These headers will now be perfectly centered due to updated drawCell
  drawCell(doc, startX, y, col1Width, tableRowHeight, 'EARNINGS', { isBold: true, align: 'center' });
  drawCell(doc, startX + col1Width, y, col2Width, tableRowHeight, 'AMOUNT', { isBold: true, align: 'center' });
  drawCell(doc, startX + col1Width + col2Width, y, col3Width, tableRowHeight, 'DEDUCTIONS', { isBold: true, align: 'center' });
  drawCell(doc, startX + col1Width + col2Width + col3Width, y, col4Width, tableRowHeight, 'AMOUNT', { isBold: true, align: 'center' });
  y += tableRowHeight;

  // === FINANCIAL DATA ===
  const earningsData = [
    { label: 'Basic Salary', value: cf.basicPay || 0 },
    { label: 'House Rent Allowance', value: cf.hra || 0 },
  ];

  const deductionsData = [
    { label: 'PF', value: deductions.pf || 0 },
    { label: 'ESI', value: deductions.esi || 0 },
    { label: 'Professional Tax', value: deductions.pt || 0 },
    { label: 'LOP', value: deductions.lop || 0 },
    { label: 'Penalities', value: deductions.penalty || 0 },
  ];

  const maxRows = Math.max(earningsData.length, deductionsData.length, 5);
  const dataBlockHeight = maxRows * tableRowHeight;

  doc.rect(startX, y, fullWidth, dataBlockHeight).stroke();
  doc.moveTo(startX + col1Width, y).lineTo(startX + col1Width, y + dataBlockHeight).stroke();
  doc.moveTo(startX + col1Width + col2Width, y).lineTo(startX + col1Width + col2Width, y + dataBlockHeight).stroke();
  doc.moveTo(startX + col1Width + col2Width + col3Width, y).lineTo(startX + col1Width + col2Width + col3Width, y + dataBlockHeight).stroke();

  let dataY = y;
  const currencySymbol = '₹';

  for (let i = 0; i < maxRows; i++) {
    const earning = earningsData[i];
    const deduction = deductionsData[i];

    if (earning) {
      // Manual text drawing for list items - kept top-aligned with padding as per original style
      doc.font('Roboto').fontSize(9)
        .text(earning.label, startX + 4, dataY + 5, { width: col1Width - 8, align: 'left' });
      doc.text(`${currencySymbol} ${earning.value.toFixed(2)}`, startX + col1Width + 4, dataY + 5, { width: col2Width - 8, align: 'center' });
    }

    if (deduction) {
      doc.text(deduction.label, startX + col1Width + col2Width + 4, dataY + 5, { width: col3Width - 8, align: 'left' });
      doc.text(`${currencySymbol} ${deduction.value.toFixed(2)}`, startX + col1Width + col2Width + col3Width + 4, dataY + 5, { width: col4Width - 8, align: 'center' });
    }
    dataY += tableRowHeight;
  }
  y += dataBlockHeight;

  // === D. SUB-TOTALS (Vertically Centered) ===
  const totalEarnings = earningsData.reduce((sum, e) => sum + e.value, 0);
  const totalDeductions = deductionsData.reduce((sum, d) => sum + d.value, 0);

  // Using drawCell ensures strict vertical centering
  drawCell(doc, startX, y, col1Width, tableRowHeight, 'Gross Earnings', { isBold: true });
  drawCell(doc, startX + col1Width, y, col2Width, tableRowHeight, `${currencySymbol} ${totalEarnings.toFixed(2)}`, { isBold: true, align: 'center' });
  drawCell(doc, startX + col1Width + col2Width, y, col3Width, tableRowHeight, 'Total Deductions', { isBold: true });
  drawCell(doc, startX + col1Width + col2Width + col3Width, y, col4Width, tableRowHeight, `${currencySymbol} ${totalDeductions.toFixed(2)}`, { isBold: true, align: 'center' });
  y += tableRowHeight;

  // === E. GAP ROW ===
  drawMergedCell(doc, startX, y, fullWidth, tableRowHeight, '');
  y += tableRowHeight;

  // === F. NETPAY SECTION (Vertically Centered) ===
  const netpayMergedWidth = col1Width + col2Width + col3Width;

  // Row 1: Header
  drawMergedCell(doc, startX, y, netpayMergedWidth, tableRowHeight, 'NETPAY', { isBold: true, align: 'left' });
  drawCell(doc, startX + netpayMergedWidth, y, col4Width, tableRowHeight, 'AMOUNT', { isBold: true, align: 'center' });
  y += tableRowHeight;

  // Row 2: Gross Recap
  drawMergedCell(doc, startX, y, netpayMergedWidth, tableRowHeight, 'Gross Earnings', { align: 'left' });
  drawCell(doc, startX + netpayMergedWidth, y, col4Width, tableRowHeight, `${currencySymbol} ${totalEarnings.toFixed(2)}`, { align: 'center' });
  y += tableRowHeight;

  // Row 3: Deductions Recap
  drawMergedCell(doc, startX, y, netpayMergedWidth, tableRowHeight, 'Total Deductions', { align: 'left' });
  drawCell(doc, startX + netpayMergedWidth, y, col4Width, tableRowHeight, `${currencySymbol} ${totalDeductions.toFixed(2)}`, { align: 'center' });
  y += tableRowHeight;

  // Row 4: Final Total
  const netSalary = totalEarnings - totalDeductions;
  drawMergedCell(doc, startX, y, netpayMergedWidth, tableRowHeight, 'Total Net Payable', { isBold: true, align: 'left' });
  drawCell(doc, startX + netpayMergedWidth, y, col4Width, tableRowHeight, `${currencySymbol} ${netSalary.toFixed(2)}`, { isBold: true, align: 'center' });
  y += tableRowHeight;

  // === G. FOOTER (Vertically Centered) ===
  const netPayWords = `Total Net Payable ${Math.floor(netSalary)},000/- (Rupees Only)`;
  drawMergedCell(doc, startX, y, fullWidth, tableRowHeight, netPayWords, { isBold: true, align: 'center' });
  y += tableRowHeight;

  drawMergedCell(doc, startX, y, fullWidth, tableRowHeight, '** Total Net Payable = Gross Earnings - Total Deductions **', { align: 'center', fontSize: 8 });
  y += tableRowHeight + 15;

  doc.font('Roboto').fontSize(8)
    .text('This is a computer generated payslip, hence no signature is required', 0, y, { align: 'center', width: 595 });
}

/**
 * MAIN WRAPPER
 */
async function generatePayslipPDF(payslipRequest) {
  const doc = new PDFDocument({ size: 'A4', margin: 0 });

  // Register Fonts
  const fontPathRegular = path.join(__dirname, '../../../hrm_app/assets/fonts/Roboto-Regular.ttf');
  const fontPathBold = path.join(__dirname, '../../../hrm_app/assets/fonts/Roboto-Bold.ttf');

  if (fs.existsSync(fontPathRegular)) doc.registerFont('Roboto', fontPathRegular);
  if (fs.existsSync(fontPathBold)) doc.registerFont('Roboto-Bold', fontPathBold);

  // ... (Your existing image path and config logic remains unchanged) ...
  const orgName = payslipRequest?.employee?.subOrganisation || '';
  const isAcademic = /Academic|Acad|Overseas/i.test(orgName);
  const logoName = isAcademic ? 'logo_ao.png' : 'logo_sst.png';
  const logoPath = path.join(__dirname, '../../../hrm_app/assets/images', logoName);

  const config = isAcademic ? {
    companyName: 'ACADEMIC OVERSEAS PVT LTD',
    address: '2nd Floor, NCK Plaza, NTR Circle, Patamata, Vijayawada, NTR District, Andhra\nPradesh.',
    hasLogo: true,
    logoPath: logoPath
  } : {
    companyName: 'SANDSPACE TECHNOLOGIES PVT LTD',
    address: '2nd Floor, NCK Plaza, NTR Circle, Patamata, Vijayawada, NTR District,\nAndhra Pradesh.',
    hasLogo: true,
    logoPath: logoPath
  };

  const writableStreamBuffer = new StreamBuffers.WritableStreamBuffer({ initialSize: 100 * 1024, incrementAmount: 10 * 1024 });
  doc.pipe(writableStreamBuffer);

  generateExactLayout(doc, payslipRequest, config);

  doc.end();
  await new Promise((resolve) => doc.on('end', resolve));
  return writableStreamBuffer.getContents();
}

module.exports = { generatePayslipPDF };