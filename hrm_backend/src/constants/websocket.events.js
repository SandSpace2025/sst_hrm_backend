// WebSocket Event Constants
// This file contains all the WebSocket event names used throughout the application

const WEBSOCKET_EVENTS = {
  // Connection Events
  CONNECTION: "connection",
  DISCONNECT: "disconnect",
  AUTHENTICATE: "authenticate",
  AUTHENTICATED: "authenticated",
  AUTHENTICATION_FAILED: "authentication_failed",

  // Room Management Events
  JOIN_ROOM: "join_room",
  LEAVE_ROOM: "leave_room",
  ROOM_JOINED: "room_joined",
  ROOM_LEFT: "room_left",

  // User Events
  USER_CONNECTED: "user_connected",
  USER_DISCONNECTED: "user_disconnected",
  USER_STATUS_CHANGED: "user_status_changed",

  // Employee Management Events
  EMPLOYEE_CREATED: "employee_created",
  EMPLOYEE_UPDATED: "employee_updated",
  EMPLOYEE_DELETED: "employee_deleted",
  EMPLOYEE_STATUS_CHANGED: "employee_status_changed",
  EMPLOYEE_PROFILE_UPDATED: "employee_profile_updated",

  // Leave Management Events
  LEAVE_REQUEST_CREATED: "leave_request_created",
  LEAVE_REQUEST_APPROVED: "leave_request_approved",
  LEAVE_REQUEST_REJECTED: "leave_request_rejected",
  LEAVE_REQUEST_CANCELLED: "leave_request_cancelled",
  LEAVE_BALANCE_UPDATED: "leave_balance_updated",
  LEAVE_CALENDAR_UPDATED: "leave_calendar_updated",

  // Payroll & Payslip Events
  PAYSLIP_REQUEST_CREATED: "payslip_request_created",
  PAYSLIP_REQUEST_APPROVED: "payslip_request_approved",
  PAYSLIP_REQUEST_REJECTED: "payslip_request_rejected",
  PAYSLIP_REQUEST_ON_HOLD: "payslip_request_on_hold",
  PAYSLIP_GENERATED: "payslip_generated",
  PAYROLL_PROCESSED: "payroll_processed",
  SALARY_UPDATED: "salary_updated",

  // Messaging System Events
  MESSAGE_SENT: "message_sent",
  MESSAGE_RECEIVED: "message_received",
  MESSAGE_READ: "message_read",
  // MESSAGE_DELETED and MESSAGE_EDITED removed for organizational security
  CONVERSATION_CREATED: "conversation_created",
  CONVERSATION_UPDATED: "conversation_updated",
  // CONVERSATION_DELETED, CONVERSATION_ARCHIVED, CONVERSATION_UNARCHIVED removed for organizational security
  TYPING_INDICATOR: "typing_indicator",
  TYPING_STOPPED: "typing_stopped",

  // End of Day (EOD) Events
  EOD_SUBMITTED: "eod_submitted",
  EOD_APPROVED: "eod_approved",
  EOD_REJECTED: "eod_rejected",
  EOD_REMINDER: "eod_reminder",
  EOD_DEADLINE_APPROACHING: "eod_deadline_approaching",

  // Announcements & Notifications
  ANNOUNCEMENT_CREATED: "announcement_created",
  ANNOUNCEMENT_UPDATED: "announcement_updated",
  ANNOUNCEMENT_DELETED: "announcement_deleted",
  NOTIFICATION_SENT: "notification_sent",
  SYSTEM_ALERT: "system_alert",

  // Attendance & Time Tracking
  CHECK_IN: "check_in",
  CHECK_OUT: "check_out",
  BREAK_START: "break_start",
  BREAK_END: "break_end",
  OVERTIME_LOGGED: "overtime_logged",
  ATTENDANCE_UPDATED: "attendance_updated",

  // Custom Events
  CUSTOM_EVENT: "custom_event",

  // Error Events
  ERROR: "error",
  RATE_LIMIT_EXCEEDED: "rate_limit_exceeded",
  INVALID_DATA: "invalid_data",

  // System Events
  SYSTEM_MAINTENANCE: "system_maintenance",
  SYSTEM_UPDATE: "system_update",
  CONNECTION_STATUS: "connection_status",
  HEARTBEAT: "heartbeat",
};

// Room Names
const WEBSOCKET_ROOMS = {
  ADMIN_ROOM: "admin_room",
  HR_ROOM: "hr_room",
  EMPLOYEE_ROOM: "employee_room",
  COMPANY_WIDE: "company_wide",
  USER_ROOM: (userId) => `user_${userId}`,
  DEPARTMENT_ROOM: (deptId) => `department_${deptId}`,
  PROJECT_ROOM: (projectId) => `project_${projectId}`,
  TEAM_ROOM: (teamId) => `team_${teamId}`,
};

// Event Categories for better organization
const EVENT_CATEGORIES = {
  CONNECTION: "connection",
  USER_MANAGEMENT: "user_management",
  EMPLOYEE_MANAGEMENT: "employee_management",
  LEAVE_MANAGEMENT: "leave_management",
  PAYROLL: "payroll",
  MESSAGING: "messaging",
  EOD: "eod",
  ANNOUNCEMENTS: "announcements",
  ATTENDANCE: "attendance",
  SYSTEM: "system",
};

// Event Priorities
const EVENT_PRIORITIES = {
  LOW: "low",
  MEDIUM: "medium",
  HIGH: "high",
  CRITICAL: "critical",
};

module.exports = {
  WEBSOCKET_EVENTS,
  WEBSOCKET_ROOMS,
  EVENT_CATEGORIES,
  EVENT_PRIORITIES,
};
