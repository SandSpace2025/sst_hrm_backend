const PDFDocument = require("pdfkit");
const StreamBuffers = require("stream-buffers");
const fs = require("fs");
const path = require("path");
const logger = require("../core/logger");

/**
 * Helper: Draw a cell with specific borders
 * UPDATED: Calculates exact vertical center based on text height
 */
function drawCell(doc, x, y, width, height, text, options = {}) {
  const {
    isBold = false,
    align = "center",
    fontSize = 9,
    borders = { top: true, right: true, bottom: true, left: true },
    valign = "middle", // Default is middle
  } = options;

  // 1. Draw borders
  doc.lineWidth(1); // Ensure line width is consistent
  if (borders.top)
    doc
      .moveTo(x, y)
      .lineTo(x + width, y)
      .stroke();
  if (borders.right)
    doc
      .moveTo(x + width, y)
      .lineTo(x + width, y + height)
      .stroke();
  if (borders.bottom)
    doc
      .moveTo(x, y + height)
      .lineTo(x + width, y + height)
      .stroke();
  if (borders.left)
    doc
      .moveTo(x, y)
      .lineTo(x, y + height)
      .stroke();

  // 2. Set Font Settings FIRST (Needed to measure height)
  // Retrieve fonts from options OR global doc configuration composed in generatePayslipPDF
  const fontRegular =
    options.fontRegular || doc.customFontRegular || "Helvetica";
  const fontBold = options.fontBold || doc.customFontBold || "Helvetica-Bold";

  const fontName = isBold ? fontBold : fontRegular;
  doc.font(fontName).fontSize(fontSize);

  // 3. Calculate Vertical Position
  let textY = y + 5; // Default padding for top alignment

  if (valign === "middle") {
    // Measure exact height of the text block
    const textHeight = doc.heightOfString(text || "", {
      width: width - 8,
      align: align,
    });
    // Formula: StartY + (BoxHeight - TextHeight) / 2
    textY = y + (height - textHeight) / 2;
  }

  // 4. Draw Text
  doc.text(text || "", x + 4, textY, {
    width: width - 8,
    align: align,
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
  // Destructure required fields with defaults
  const {
    calculatedFields: cf = {},
    deductions = {},
    employee = {},
    payslipDetails: details = {},
  } = payslipRequest;

  // logger.info("Layout Configuration Loaded");
  // === CONFIGURATION ===
  const pageMargin = 30;
  const fullWidth = 535;
  const startX = pageMargin;

  // 4-Column Grid Definition
  const col1Width = fullWidth * 0.28; // Earnings Description
  const col2Width = fullWidth * 0.22; // Earnings Amount
  const col3Width = fullWidth * 0.28; // Deductions Description
  const col4Width = fullWidth * 0.22; // Deductions Amount

  let y = 30;
  doc.lineWidth(1);

  // === A. HEADER SECTION ===
  const headerHeight = 130;
  const logoWidth = 130; // Configured for bigger logo
  const companyInfoWidth = fullWidth - logoWidth;

  doc.rect(startX, y, fullWidth, headerHeight).stroke();

  // --- 1. DRAW LOGO ---

  if (config.hasLogo && config.logoPath && fs.existsSync(config.logoPath)) {
    try {
      // Check file size to ensure it's a valid image
      // logger.info(`Logo file found - Size: ${stats.size} bytes`);
      doc.image(config.logoPath, startX + 15, y + 10, {
        fit: [logoWidth - 20, headerHeight - 20],
        align: "center",
        valign: "center",
      });
    } catch (err) {
      logger.error("Logo image rendering error", {
        error: err.message,
        stack: err.stack,
      });
    }
  } else {
    logger.warn("Logo not rendered - Conditions not met", {
      hasLogo: config.hasLogo,
      logoPath: config.logoPath,
      exists: config.logoPath ? fs.existsSync(config.logoPath) : "N/A",
    });
  }

  // --- 2. DRAW TEXT ---
  const textX = startX + logoWidth;
  const cleanAddress = config.address.replace(/\n/g, " ");

  // Company Name
  doc
    .font(doc.customFontBold)
    .fontSize(20)
    .text(config.companyName, textX, y + 28, {
      width: companyInfoWidth,
      align: "center",
    });

  // Address
  doc
    .font(doc.customFontRegular)
    .fontSize(8)
    .text(cleanAddress, textX, y + 55, {
      width: companyInfoWidth,
      align: "center",
    });

  // Payslip Title
  doc
    .font(doc.customFontBold)
    .fontSize(12)
    .text(
      `Payslip for the month of ${payslipRequest.startMonth} ${payslipRequest.startYear}`,
      textX,
      y + 90,
      { width: companyInfoWidth, align: "center" },
    );

  y += headerHeight;

  // === B. EMPLOYEE PAY SUMMARY (Vertical Layout) ===
  const summaryRowHeight = 16;
  const leftHalfWidth = col1Width + col2Width;
  // const rightHalfWidth = col3Width + col4Width; // Unused, but calculation implies split

  // Header: "Employee Pay Summary" (Auto-centered by updated drawMergedCell)
  drawMergedCell(
    doc,
    startX,
    y,
    fullWidth,
    summaryRowHeight,
    "Employee Pay Summary",
    { isBold: true, fontSize: 10 },
  );
  y += summaryRowHeight;

  // Helper to safely format date
  const safeDate = (dateStr) => {
    if (!dateStr) return "N/A";
    try {
      const d = new Date(dateStr);
      if (isNaN(d.getTime())) return "N/A";
      return d.toLocaleDateString("en-IN", {
        day: "2-digit",
        month: "2-digit",
        year: "numeric",
      });
    } catch (e) {
      return "N/A";
    }
  };

  // --- DYNAMIC PAID DAYS CALCULATION ---
  const getDaysInMonth = (monthName, year) => {
    const monthMap = {
      january: 0,
      february: 1,
      march: 2,
      april: 3,
      may: 4,
      june: 5,
      july: 6,
      august: 7,
      september: 8,
      october: 9,
      november: 10,
      december: 11,
    };
    const monthIdx = monthMap[monthName.toLowerCase()];
    if (monthIdx === undefined) return 30; // Fallback
    return new Date(year, monthIdx + 1, 0).getDate();
  };

  const totalDays = getDaysInMonth(
    payslipRequest.startMonth,
    payslipRequest.startYear,
  );
  const lopDays = Number(details.lopDays) || 0;
  const paidDays = totalDays - lopDays;
  // -------------------------------------

  // Helper for Indian Currency Formatting
  const formatAmount = (amount) => {
    const num = Number(amount) || 0;
    return num.toLocaleString("en-IN", {
      minimumFractionDigits: 2,
      maximumFractionDigits: 2,
    });
  };

  const employeeLines = [
    {
      left: `Employee Name :`,
      leftVal: employee.name || "",
      right: "PAN:",
      rightVal: details.pan || "",
    },
    {
      left: `Employee ID :`,
      leftVal: employee.employeeId || "",
      right: "Bank Name:",
      rightVal: details.bankName || "",
    },
    {
      left: `Designation :`,
      leftVal: employee.jobTitle || "",
      right: "Account Number:",
      rightVal: details.accountNumber || "",
    },
    {
      left: `Joining Date :`,
      leftVal: safeDate(employee.joinDate),
      right: "Paid Days:", // Custom handled below for split
      rightVal: `${paidDays}       LOP Days: ${lopDays}`, // Combined with spacing
    },
    {
      left: `Pay Period :`,
      leftVal: `${payslipRequest.startMonth} ${payslipRequest.startYear}`,
      right: "PF Number:", // Moved here to use empty space, or leave blank if strict
      rightVal: details.pfNumber || "",
    },
  ];

  const summaryBlockHeight = employeeLines.length * summaryRowHeight;

  // Draw Outer Box and Middle Divider
  doc.rect(startX, y, fullWidth, summaryBlockHeight).stroke();
  doc
    .moveTo(startX + leftHalfWidth, y)
    .lineTo(startX + leftHalfWidth, y + summaryBlockHeight)
    .stroke();

  let tempY = y;
  for (let i = 0; i < employeeLines.length; i++) {
    const line = employeeLines[i];
    // Note: We use manual doc.text here for the list items to control specific left/right spacing
    // We center them vertically using manual math (tempY + 3) which looks good for this font size
    if (line.left)
      doc
        .font(doc.customFontBold) // Bold Labels
        .fontSize(9)
        .text(line.left, startX + 4, tempY + 4, { continued: true })
        .font(doc.customFontRegular)
        .text(` ${line.leftVal}`);

    if (line.right) {
      // Special case for Paid Days / LOP Days
      if (line.right === "Paid Days:") {
        doc
          .font(doc.customFontBold)
          .fontSize(9)
          .text("Paid Days: ", startX + leftHalfWidth + 4, tempY + 4, {
            continued: true,
          })
          .font(doc.customFontRegular)
          .text(`${paidDays}          `, { continued: true })
          .font(doc.customFontBold)
          .text("LOP Days: ", { continued: true })
          .font(doc.customFontRegular)
          .text(`${lopDays}`);
      } else {
        doc
          .font(doc.customFontBold)
          .fontSize(9)
          .text(line.right, startX + leftHalfWidth + 4, tempY + 4, {
            continued: true,
          })
          .font(doc.customFontRegular)
          .text(` ${line.rightVal}`);
      }
    }
    tempY += summaryRowHeight;
  }

  y += summaryBlockHeight;

  // === C. FINANCIAL TABLE HEADERS ===
  const tableRowHeight = 20;

  // These headers will now be perfectly centered due to updated drawCell
  drawCell(doc, startX, y, col1Width, tableRowHeight, "EARNINGS", {
    isBold: true,
    align: "left", // Image shows left aligned usually, but code had center. Image header is BOLD.
    // Actually image headers: EARNINGS (Left?), AMOUNT (Center?)
    // Let's stick to simple centering or left with bold similar to image
    align: "left", // Matches typical receipts
  });
  drawCell(doc, startX + col1Width, y, col2Width, tableRowHeight, "AMOUNT", {
    isBold: true,
    align: "right", // Amounts usually right aligned
  });
  drawCell(
    doc,
    startX + col1Width + col2Width,
    y,
    col3Width,
    tableRowHeight,
    "DEDUCTIONS",
    { isBold: true, align: "left" },
  );
  drawCell(
    doc,
    startX + col1Width + col2Width + col3Width,
    y,
    col4Width,
    tableRowHeight,
    "AMOUNT",
    { isBold: true, align: "right" },
  );
  y += tableRowHeight;

  // === FINANCIAL DATA ===
  // Helper to safely get number value
  const safeNum = (val) => {
    const n = Number(val);
    return isNaN(n) ? 0 : n;
  };

  const earningsData = [
    { label: "Basic Salary", value: safeNum(cf.basicPay) },
    { label: "House Rent Allowance", value: safeNum(cf.hra) },
    { label: "Conveyance Allowance", value: safeNum(cf.conveyance) },
    { label: "Special Allowance", value: safeNum(cf.specialAllowance) },
  ];

  const deductionsData = [
    { label: "PF", value: safeNum(deductions.pf) },
    { label: "Professional Tax", value: safeNum(deductions.pt) }, // Swapped order to match image? Image: PF, PT, LOP, Penalties
    { label: "LOP", value: safeNum(deductions.lop) },
    { label: "Penalities", value: safeNum(deductions.penalty) },
    // ESI seemingly not in image usage but we keep it if not 0?
    // Or maybe just append it. Image prevents "ESI" if 0.
    // Let's add ESI if > 0 just to be safe, or stick to list.
    { label: "ESI", value: safeNum(deductions.esi) },
  ];

  const maxRows = Math.max(earningsData.length, deductionsData.length, 5);
  const dataBlockHeight = maxRows * tableRowHeight;

  doc.rect(startX, y, fullWidth, dataBlockHeight).stroke();
  doc
    .moveTo(startX + col1Width, y)
    .lineTo(startX + col1Width, y + dataBlockHeight)
    .stroke();
  doc
    .moveTo(startX + col1Width + col2Width, y)
    .lineTo(startX + col1Width + col2Width, y + dataBlockHeight)
    .stroke();
  doc
    .moveTo(startX + col1Width + col2Width + col3Width, y)
    .lineTo(startX + col1Width + col2Width + col3Width, y + dataBlockHeight)
    .stroke();

  let dataY = y;
  const currencySymbol = "₹"; // Rupee Symbol

  console.log("[Payslip-Gen] Drawing Financial Data Rows...");
  for (let i = 0; i < maxRows; i++) {
    const earning = earningsData[i];
    const deduction = deductionsData[i];

    if (earning) {
      // Manual text drawing for list items - kept top-aligned with padding as per original style
      doc
        .font(doc.customFontRegular)
        .fontSize(9)
        .text(earning.label, startX + 4, dataY + 5, {
          width: col1Width - 8,
          align: "left",
        });
      doc.text(
        `${currencySymbol} ${formatAmount(earning.value)}`,
        startX + col1Width + 4,
        dataY + 5,
        { width: col2Width - 8, align: "right" },
      );
    }

    if (deduction) {
      doc.text(deduction.label, startX + col1Width + col2Width + 4, dataY + 5, {
        width: col3Width - 8,
        align: "left",
      });
      doc.text(
        `${currencySymbol} ${formatAmount(deduction.value)}`,
        startX + col1Width + col2Width + col3Width + 4,
        dataY + 5,
        { width: col4Width - 8, align: "right" },
      );
    }
    dataY += tableRowHeight;
  }
  y += dataBlockHeight;

  // === D. SUB-TOTALS (Vertically Centered) ===
  const totalEarnings = earningsData.reduce((sum, e) => sum + e.value, 0);
  const totalDeductions = deductionsData.reduce((sum, d) => sum + d.value, 0);

  // Using drawCell ensures strict vertical centering
  drawCell(doc, startX, y, col1Width, tableRowHeight, "Gross Earnings", {
    isBold: true,
  });
  drawCell(
    doc,
    startX + col1Width,
    y,
    col2Width,
    tableRowHeight,
    `${currencySymbol} ${formatAmount(totalEarnings)}`,
    { isBold: true, align: "right" },
  );
  drawCell(
    doc,
    startX + col1Width + col2Width,
    y,
    col3Width,
    tableRowHeight,
    "Total Deductions",
    { isBold: true },
  );
  drawCell(
    doc,
    startX + col1Width + col2Width + col3Width,
    y,
    col4Width,
    tableRowHeight,
    `${currencySymbol} ${formatAmount(totalDeductions)}`,
    { isBold: true, align: "right" },
  );
  y += tableRowHeight;

  // === E. GAP ROW ===
  drawMergedCell(doc, startX, y, fullWidth, tableRowHeight, "");
  y += tableRowHeight;

  // === F. NETPAY SECTION (Vertically Centered) ===
  const netpayMergedWidth = col1Width + col2Width + col3Width;

  // Row 1: Header - actually image shows "NETPAY" just followed by AMOUNT column header effectively?
  // Image: | NETPAY | | | AMOUNT |  (Structure-wise)
  // Let's stick to current structure but fix alignment
  drawMergedCell(doc, startX, y, netpayMergedWidth, tableRowHeight, "NETPAY", {
    isBold: true,
    align: "left",
  });
  drawCell(
    doc,
    startX + netpayMergedWidth,
    y,
    col4Width,
    tableRowHeight,
    "AMOUNT",
    { isBold: true, align: "right" },
  );
  y += tableRowHeight;

  // Row 2: Gross Recap
  drawMergedCell(
    doc,
    startX,
    y,
    netpayMergedWidth,
    tableRowHeight,
    "Gross Earnings",
    { align: "left" },
  );
  drawCell(
    doc,
    startX + netpayMergedWidth,
    y,
    col4Width,
    tableRowHeight,
    `${currencySymbol} ${formatAmount(totalEarnings)}`,
    { align: "right" },
  );
  y += tableRowHeight;

  // Row 3: Deductions Recap
  drawMergedCell(
    doc,
    startX,
    y,
    netpayMergedWidth,
    tableRowHeight,
    "Total Deductions",
    { align: "left" },
  );
  drawCell(
    doc,
    startX + netpayMergedWidth,
    y,
    col4Width,
    tableRowHeight,
    `${currencySymbol} ${formatAmount(totalDeductions)}`,
    { align: "right" },
  );
  y += tableRowHeight;

  // Row 4: Final Total
  const netSalary = totalEarnings - totalDeductions;
  drawMergedCell(
    doc,
    startX,
    y,
    netpayMergedWidth,
    tableRowHeight,
    "Total Net Payable",
    { isBold: true, align: "left" },
  );
  drawCell(
    doc,
    startX + netpayMergedWidth,
    y,
    col4Width,
    tableRowHeight,
    `${currencySymbol} ${formatAmount(netSalary)}`,
    { isBold: true, align: "right" },
  );
  y += tableRowHeight;

  // === G. FOOTER (Vertically Centered) ===
  const netPayWords = `Total Net Payable ${Math.floor(netSalary)},000/- (Rupees Only)`;
  drawMergedCell(doc, startX, y, fullWidth, tableRowHeight, netPayWords, {
    isBold: true,
    align: "center",
  });
  y += tableRowHeight;

  drawMergedCell(
    doc,
    startX,
    y,
    fullWidth,
    tableRowHeight,
    "** Total Net Payable = Gross Earnings - Total Deductions **",
    { align: "center", fontSize: 8 },
  );
  y += tableRowHeight + 15;

  doc
    .font(doc.customFontRegular)
    .fontSize(8)
    .text(
      "This is a computer generated payslip, hence no signature is required",
      0,
      y,
      { align: "center", width: 595 },
    );
}

/**
 * MAIN WRAPPER
 */
async function generatePayslipPDF(payslipRequest) {
  const doc = new PDFDocument({ size: "A4", margin: 0 });

  // Register Fonts with Robust Fallback
  const fontPathRegular = path.join(
    __dirname,
    "../../../hrm_app/assets/fonts/Roboto-Regular.ttf",
  );
  const fontPathBold = path.join(
    __dirname,
    "../../../hrm_app/assets/fonts/Roboto-Bold.ttf",
  );

  let fontRegular = "Helvetica";
  let fontBold = "Helvetica-Bold";

  try {
    if (fs.existsSync(fontPathRegular)) {
      doc.registerFont("Roboto", fontPathRegular);
      fontRegular = "Roboto";
      // logger.info("Registered Roboto Regular");
    } else {
      logger.warn("Roboto font not found, using Helvetica", {
        path: fontPathRegular,
      });
    }

    if (fs.existsSync(fontPathBold)) {
      doc.registerFont("Roboto-Bold", fontPathBold);
      fontBold = "Roboto-Bold";
      // logger.info("Registered Roboto Bold");
    } else {
      logger.warn("Roboto-Bold font not found, using Helvetica-Bold", {
        path: fontPathBold,
      });
    }
  } catch (e) {
    logger.error("Error registering fonts", { error: e.message });
    // Fallback defaults remain Helvetica
  }

  // Attach resolved font names to doc for helpers to use
  doc.customFontRegular = fontRegular;
  doc.customFontBold = fontBold;

  // logger.info(`Fonts resolved -> Regular: ${fontRegular}, Bold: ${fontBold}`);

  // ... (Your existing image path and config logic remains unchanged) ...
  const orgName = payslipRequest?.employee?.subOrganisation || "";
  const isAcademic = /Academic|Acad|Overseas/i.test(orgName);
  const logoName = isAcademic ? "logo_ao.png" : "logo_sst.png";

  // Robust Path Resolution for Logo
  // Prioritize backend's own assets folder since backend runs separately from frontend
  const possiblePaths = [
    path.join(__dirname, "../assets/images", logoName), // Backend assets (PREFERRED)
    path.join(__dirname, "../../assets/images", logoName), // Alternative backend location
    path.join(__dirname, "../../../hrm_app/assets/images", logoName), // Frontend fallback (if repos side-by-side)
    path.join(process.cwd(), "src/assets/images", logoName), // From backend root
    path.join(process.cwd(), "assets/images", logoName), // Alternative root
  ];

  let logoPath = "";
  for (const p of possiblePaths) {
    if (fs.existsSync(p)) {
      logoPath = p;
      break;
    }
  }

  // logger.info(`Organization: ${orgName}, Logo: ${logoName}, Path: ${logoPath}`);
  if (!logoPath) {
    logger.warn("Logo file not found in tested paths", {
      testedPaths: possiblePaths,
    });
  }

  const config = isAcademic
    ? {
        companyName: "ACADEMIC OVERSEAS PVT LTD",
        address:
          "2nd Floor, NCK Plaza, NTR Circle, Patamata, Vijayawada, NTR District, Andhra\nPradesh.",
        hasLogo: !!logoPath,
        logoPath: logoPath,
      }
    : {
        companyName: "SANDSPACE TECHNOLOGIES PVT LTD",
        address:
          "2nd Floor, NCK Plaza, NTR Circle, Patamata, Vijayawada, NTR District,\nAndhra Pradesh.",
        hasLogo: !!logoPath,
        logoPath: logoPath,
      };

  const writableStreamBuffer = new StreamBuffers.WritableStreamBuffer({
    initialSize: 100 * 1024,
    incrementAmount: 10 * 1024,
  });
  doc.pipe(writableStreamBuffer);

  // logger.info("Starting Exact Layout Generation");
  try {
    generateExactLayout(doc, payslipRequest, {
      ...config,
      fontRegular,
      fontBold,
    });
    // logger.info("Exact Layout Generation Completed");
  } catch (layoutError) {
    logger.error("Critical error inside generateExactLayout", {
      error: layoutError.message,
      stack: layoutError.stack,
    });
    throw layoutError; // Re-throw to be caught by controller
  }

  doc.end();
  await new Promise((resolve) => doc.on("end", resolve));
  return writableStreamBuffer.getContents();
}

module.exports = { generatePayslipPDF };
