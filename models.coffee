mongoose = require 'mongoose'

ReportSchema = new mongoose.Schema
  date:
    type: Date
    default: Date.now
  companyId: Number
  gender:
    type: String
    enum: ['male', 'female']
  ratio:
    female: Number
    male: Number
  culture: [String]
  culture_text: String
  personality: Boolean
  promotion: Boolean
  raise: Boolean
  raise_percentage: Number
  salary: Number

Report = mongoose.model 'Report', ReportSchema
module.exports.report = Report
