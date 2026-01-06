const Holiday = require("../models/holiday.model");

// Create a new holiday
exports.createHoliday = async (req, res) => {
  try {
    const { date, name, description } = req.body;
    const userId = req.userId;

    if (!date || !name) {
      return res.status(400).json({ message: "Date and Name are required" });
    }

    const holidayDate = new Date(date);
    const existingHoliday = await Holiday.findOne({ date: holidayDate });
    if (existingHoliday) {
      return res
        .status(400)
        .json({ message: "Holiday already exists for this date" });
    }

    const holiday = new Holiday({
      date: holidayDate,
      name,
      description,
      year: holidayDate.getFullYear(),
      createdBy: userId,
    });

    await holiday.save();
    res
      .status(201)
      .json({ message: "Holiday created successfully", data: holiday });
  } catch (error) {
    console.error("Create Holiday Error:", error);
    res.status(500).json({ message: "Server Error", error: error.message });
  }
};

// Get all holidays (optional year filter)
exports.getHolidays = async (req, res) => {
  try {
    const { year, month } = req.query;
    let query = {};

    if (year) {
      query.year = parseInt(year);
    }

    if (month && year) {
      const startDate = new Date(parseInt(year), parseInt(month) - 1, 1);
      const endDate = new Date(parseInt(year), parseInt(month), 0, 23, 59, 59);
      query.date = { $gte: startDate, $lte: endDate };
    }

    const holidays = await Holiday.find(query).sort({ date: 1 });
    res.status(200).json({ data: holidays });
  } catch (error) {
    console.error("Get Holidays Error:", error);
    res.status(500).json({ message: "Server Error", error: error.message });
  }
};

// Delete a holiday
exports.deleteHoliday = async (req, res) => {
  try {
    const { id } = req.params;
    const holiday = await Holiday.findByIdAndDelete(id);

    if (!holiday) {
      return res.status(404).json({ message: "Holiday not found" });
    }

    res.status(200).json({ message: "Holiday deleted successfully" });
  } catch (error) {
    console.error("Delete Holiday Error:", error);
    res.status(500).json({ message: "Server Error", error: error.message });
  }
};
