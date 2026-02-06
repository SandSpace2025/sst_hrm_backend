const websocketService = require("../services/websocket.service");
const {
  WEBSOCKET_EVENTS,
  WEBSOCKET_ROOMS,
} = require("../constants/websocket.events");

/**
 * WebSocket Event Handlers
 * This file contains all the event handling logic for WebSocket events
 */

class WebSocketHandlers {
  constructor() {
    this.setupEventHandlers();
  }

  setupEventHandlers() {
    // Employee Management Events
    this.handleEmployeeCreated = this.handleEmployeeCreated.bind(this);
    this.handleEmployeeUpdated = this.handleEmployeeUpdated.bind(this);
    this.handleEmployeeDeleted = this.handleEmployeeDeleted.bind(this);
    this.handleEmployeeStatusChanged =
      this.handleEmployeeStatusChanged.bind(this);

    // Leave Management Events
    this.handleLeaveRequestCreated = this.handleLeaveRequestCreated.bind(this);
    this.handleLeaveRequestApproved =
      this.handleLeaveRequestApproved.bind(this);
    this.handleLeaveRequestRejected =
      this.handleLeaveRequestRejected.bind(this);
    this.handleLeaveBalanceUpdated = this.handleLeaveBalanceUpdated.bind(this);

    // Payroll Events
    this.handlePayslipRequestCreated =
      this.handlePayslipRequestCreated.bind(this);
    this.handlePayslipRequestApproved =
      this.handlePayslipRequestApproved.bind(this);
    this.handlePayslipRequestRejected =
      this.handlePayslipRequestRejected.bind(this);
    this.handlePayslipGenerated = this.handlePayslipGenerated.bind(this);

    // Messaging Events
    this.handleMessageSent = this.handleMessageSent.bind(this);
    this.handleMessageReceived = this.handleMessageReceived.bind(this);
    this.handleMessageRead = this.handleMessageRead.bind(this);

    // EOD Events
    this.handleEODSubmitted = this.handleEODSubmitted.bind(this);
    this.handleEODApproved = this.handleEODApproved.bind(this);
    this.handleEODRejected = this.handleEODRejected.bind(this);

    // Announcement Events
    this.handleAnnouncementCreated = this.handleAnnouncementCreated.bind(this);
    this.handleAnnouncementUpdated = this.handleAnnouncementUpdated.bind(this);
    this.handleAnnouncementDeleted = this.handleAnnouncementDeleted.bind(this);
  }

  // Employee Management Event Handlers
  handleEmployeeCreated(employeeData) {
    // console.log("📢 Employee Created Event:", employeeData);

    // Notify HR and Admin rooms
    websocketService.broadcastToRoom(
      WEBSOCKET_ROOMS.HR_ROOM,
      WEBSOCKET_EVENTS.EMPLOYEE_CREATED,
      {
        employee: employeeData,
        message: "New employee has been added to the system",
      }
    );

    websocketService.broadcastToRoom(
      WEBSOCKET_ROOMS.ADMIN_ROOM,
      WEBSOCKET_EVENTS.EMPLOYEE_CREATED,
      {
        employee: employeeData,
        message: "New employee has been added to the system",
      }
    );
  }

  handleEmployeeUpdated(employeeData) {
    // console.log("📢 Employee Updated Event:", employeeData);

    // Notify HR and Admin rooms
    websocketService.broadcastToRoom(
      WEBSOCKET_ROOMS.HR_ROOM,
      WEBSOCKET_EVENTS.EMPLOYEE_UPDATED,
      {
        employee: employeeData,
        message: "Employee information has been updated",
      }
    );

    websocketService.broadcastToRoom(
      WEBSOCKET_ROOMS.ADMIN_ROOM,
      WEBSOCKET_EVENTS.EMPLOYEE_UPDATED,
      {
        employee: employeeData,
        message: "Employee information has been updated",
      }
    );

    // Notify the employee if it's their own profile
    websocketService.broadcastToUser(
      employeeData.user,
      WEBSOCKET_EVENTS.EMPLOYEE_PROFILE_UPDATED,
      {
        employee: employeeData,
        message: "Your profile has been updated",
      }
    );
  }

  handleEmployeeDeleted(employeeData) {
    // console.log("📢 Employee Deleted Event:", employeeData);

    // Notify HR and Admin rooms
    websocketService.broadcastToRoom(
      WEBSOCKET_ROOMS.HR_ROOM,
      WEBSOCKET_EVENTS.EMPLOYEE_DELETED,
      {
        employee: employeeData,
        message: "Employee has been removed from the system",
      }
    );

    websocketService.broadcastToRoom(
      WEBSOCKET_ROOMS.ADMIN_ROOM,
      WEBSOCKET_EVENTS.EMPLOYEE_DELETED,
      {
        employee: employeeData,
        message: "Employee has been removed from the system",
      }
    );
  }

  handleEmployeeStatusChanged(employeeData) {
    // console.log("📢 Employee Status Changed Event:", employeeData);

    // Notify HR and Admin rooms
    websocketService.broadcastToRoom(
      WEBSOCKET_ROOMS.HR_ROOM,
      WEBSOCKET_EVENTS.EMPLOYEE_STATUS_CHANGED,
      {
        employee: employeeData,
        message: `Employee status changed to ${employeeData.status}`,
      }
    );

    websocketService.broadcastToRoom(
      WEBSOCKET_ROOMS.ADMIN_ROOM,
      WEBSOCKET_EVENTS.EMPLOYEE_STATUS_CHANGED,
      {
        employee: employeeData,
        message: `Employee status changed to ${employeeData.status}`,
      }
    );

    // Notify the employee
    websocketService.broadcastToUser(
      employeeData.user,
      WEBSOCKET_EVENTS.EMPLOYEE_STATUS_CHANGED,
      {
        employee: employeeData,
        message: `Your status has been changed to ${employeeData.status}`,
      }
    );
  }

  // Leave Management Event Handlers
  handleLeaveRequestCreated(leaveData) {
    // console.log("📢 Leave Request Created Event:", leaveData);

    // Notify HR and Admin rooms
    websocketService.broadcastToRoom(
      WEBSOCKET_ROOMS.HR_ROOM,
      WEBSOCKET_EVENTS.LEAVE_REQUEST_CREATED,
      {
        leaveRequest: leaveData,
        message: "New leave request has been submitted",
      }
    );

    websocketService.broadcastToRoom(
      WEBSOCKET_ROOMS.ADMIN_ROOM,
      WEBSOCKET_EVENTS.LEAVE_REQUEST_CREATED,
      {
        leaveRequest: leaveData,
        message: "New leave request has been submitted",
      }
    );
  }

  handleLeaveRequestApproved(leaveData) {
    // console.log("📢 Leave Request Approved Event:", leaveData);

    // Notify HR and Admin rooms
    websocketService.broadcastToRoom(
      WEBSOCKET_ROOMS.HR_ROOM,
      WEBSOCKET_EVENTS.LEAVE_REQUEST_APPROVED,
      {
        leaveRequest: leaveData,
        message: "Leave request has been approved",
      }
    );

    websocketService.broadcastToRoom(
      WEBSOCKET_ROOMS.ADMIN_ROOM,
      WEBSOCKET_EVENTS.LEAVE_REQUEST_APPROVED,
      {
        leaveRequest: leaveData,
        message: "Leave request has been approved",
      }
    );

    // Notify the employee
    websocketService.broadcastToUser(
      leaveData.employee.user,
      WEBSOCKET_EVENTS.LEAVE_REQUEST_APPROVED,
      {
        leaveRequest: leaveData,
        message: "Your leave request has been approved",
      }
    );

    // Update leave calendar for all users
    websocketService.broadcastToRoom(
      WEBSOCKET_ROOMS.COMPANY_WIDE,
      WEBSOCKET_EVENTS.LEAVE_CALENDAR_UPDATED,
      {
        employee: leaveData.employee,
        startDate: leaveData.startDate,
        endDate: leaveData.endDate,
        leaveType: leaveData.leaveType,
        status: "approved",
      }
    );
  }

  handleLeaveRequestRejected(leaveData) {
    // console.log("📢 Leave Request Rejected Event:", leaveData);

    // Notify HR and Admin rooms
    websocketService.broadcastToRoom(
      WEBSOCKET_ROOMS.HR_ROOM,
      WEBSOCKET_EVENTS.LEAVE_REQUEST_REJECTED,
      {
        leaveRequest: leaveData,
        message: "Leave request has been rejected",
      }
    );

    websocketService.broadcastToRoom(
      WEBSOCKET_ROOMS.ADMIN_ROOM,
      WEBSOCKET_EVENTS.LEAVE_REQUEST_REJECTED,
      {
        leaveRequest: leaveData,
        message: "Leave request has been rejected",
      }
    );

    // Notify the employee
    websocketService.broadcastToUser(
      leaveData.employee.user,
      WEBSOCKET_EVENTS.LEAVE_REQUEST_REJECTED,
      {
        leaveRequest: leaveData,
        message: "Your leave request has been rejected",
      }
    );
  }

  handleLeaveBalanceUpdated(leaveData) {
    // console.log("📢 Leave Balance Updated Event:", leaveData);

    // Notify the employee
    websocketService.broadcastToUser(
      leaveData.employeeId,
      WEBSOCKET_EVENTS.LEAVE_BALANCE_UPDATED,
      {
        leaveBalance: leaveData.leaveBalance,
        message: "Your leave balance has been updated",
      }
    );
  }

  // Payroll Event Handlers
  handlePayslipRequestCreated(payslipData) {
    // console.log("📢 Payslip Request Created Event:", payslipData);

    // Notify HR room
    websocketService.broadcastToRoom(
      WEBSOCKET_ROOMS.HR_ROOM,
      WEBSOCKET_EVENTS.PAYSLIP_REQUEST_CREATED,
      {
        payslipRequest: payslipData,
        message: "New payslip request has been submitted",
      }
    );
  }

  handlePayslipRequestApproved(payslipData) {
    // console.log("📢 Payslip Request Approved Event:", payslipData);

    // Notify HR room
    websocketService.broadcastToRoom(
      WEBSOCKET_ROOMS.HR_ROOM,
      WEBSOCKET_EVENTS.PAYSLIP_REQUEST_APPROVED,
      {
        payslipRequest: payslipData,
        message: "Payslip request has been approved",
      }
    );

    // Notify the employee
    websocketService.broadcastToUser(
      payslipData.employee.user,
      WEBSOCKET_EVENTS.PAYSLIP_REQUEST_APPROVED,
      {
        payslipRequest: payslipData,
        message: "Your payslip request has been approved",
      }
    );
  }

  handlePayslipRequestRejected(payslipData) {
    // console.log("📢 Payslip Request Rejected Event:", payslipData);

    // Notify HR room
    websocketService.broadcastToRoom(
      WEBSOCKET_ROOMS.HR_ROOM,
      WEBSOCKET_EVENTS.PAYSLIP_REQUEST_REJECTED,
      {
        payslipRequest: payslipData,
        message: "Payslip request has been rejected",
      }
    );

    // Notify the employee
    websocketService.broadcastToUser(
      payslipData.employee.user,
      WEBSOCKET_EVENTS.PAYSLIP_REQUEST_REJECTED,
      {
        payslipRequest: payslipData,
        message: "Your payslip request has been rejected",
      }
    );
  }

  handlePayslipGenerated(payslipData) {
    // console.log("📢 Payslip Generated Event:", payslipData);

    // Notify the employee
    websocketService.broadcastToUser(
      payslipData.employeeId,
      WEBSOCKET_EVENTS.PAYSLIP_GENERATED,
      {
        payslip: payslipData,
        message: "Your payslip has been generated and is ready for download",
      }
    );
  }

  // Messaging Event Handlers
  handleMessageSent(messageData) {
    // console.log("📢 Message Sent Event:", messageData);

    // Notify the sender (confirmation)
    websocketService.broadcastToUser(
      messageData.senderId,
      WEBSOCKET_EVENTS.MESSAGE_SENT,
      {
        message: messageData,
        confirmation: "Your message has been sent successfully",
      }
    );
  }

  handleMessageReceived(messageData) {
    // console.log("📢 Message Received Event:", messageData);

    // Notify the receiver
    websocketService.broadcastToUser(
      messageData.receiverId,
      WEBSOCKET_EVENTS.MESSAGE_RECEIVED,
      {
        message: messageData,
        notification: "You have received a new message",
      }
    );
  }

  handleMessageRead(messageData) {
    // console.log("📢 Message Read Event:", messageData);

    // Notify the sender that their message was read
    websocketService.broadcastToUser(
      messageData.senderId,
      WEBSOCKET_EVENTS.MESSAGE_READ,
      {
        message: messageData,
        readAt: new Date(),
      }
    );
  }

  // EOD Event Handlers
  handleEODSubmitted(eodData) {
    // console.log("📢 EOD Submitted Event:", eodData);

    // Notify HR and Admin rooms
    websocketService.broadcastToRoom(
      WEBSOCKET_ROOMS.HR_ROOM,
      WEBSOCKET_EVENTS.EOD_SUBMITTED,
      {
        eod: eodData,
        message: "New EOD has been submitted",
      }
    );

    websocketService.broadcastToRoom(
      WEBSOCKET_ROOMS.ADMIN_ROOM,
      WEBSOCKET_EVENTS.EOD_SUBMITTED,
      {
        eod: eodData,
        message: "New EOD has been submitted",
      }
    );
  }

  handleEODApproved(eodData) {
    // console.log("📢 EOD Approved Event:", eodData);

    // Notify the employee
    websocketService.broadcastToUser(
      eodData.employeeId,
      WEBSOCKET_EVENTS.EOD_APPROVED,
      {
        eod: eodData,
        message: "Your EOD has been approved",
      }
    );
  }

  handleEODRejected(eodData) {
    // console.log("📢 EOD Rejected Event:", eodData);

    // Notify the employee
    websocketService.broadcastToUser(
      eodData.employeeId,
      WEBSOCKET_EVENTS.EOD_REJECTED,
      {
        eod: eodData,
        message: "Your EOD has been rejected",
      }
    );
  }

  // Announcement Event Handlers
  handleAnnouncementCreated(announcementData) {
    // console.log("📢 Announcement Created Event:", announcementData);

    // Notify all users
    websocketService.broadcastToRoom(
      WEBSOCKET_ROOMS.COMPANY_WIDE,
      WEBSOCKET_EVENTS.ANNOUNCEMENT_CREATED,
      {
        announcement: announcementData,
        message: "New announcement has been published",
      }
    );
  }

  handleAnnouncementUpdated(announcementData) {
    // console.log("📢 Announcement Updated Event:", announcementData);

    // Notify all users
    websocketService.broadcastToRoom(
      WEBSOCKET_ROOMS.COMPANY_WIDE,
      WEBSOCKET_EVENTS.ANNOUNCEMENT_UPDATED,
      {
        announcement: announcementData,
        message: "Announcement has been updated",
      }
    );
  }

  handleAnnouncementDeleted(announcementData) {
    // console.log("📢 Announcement Deleted Event:", announcementData);

    // Notify all users
    websocketService.broadcastToRoom(
      WEBSOCKET_ROOMS.COMPANY_WIDE,
      WEBSOCKET_EVENTS.ANNOUNCEMENT_DELETED,
      {
        announcement: announcementData,
        message: "Announcement has been deleted",
      }
    );
  }

  // Utility method to emit custom events
  emitCustomEvent(eventName, data, targetRoom = null, targetUser = null) {
    // console.log(`📢 Custom Event: ${eventName}`, data);

    if (targetUser) {
      websocketService.broadcastToUser(targetUser, eventName, data);
    } else if (targetRoom) {
      websocketService.broadcastToRoom(targetRoom, eventName, data);
    } else {
      websocketService.broadcastToAll(eventName, data);
    }
  }

  // Get connection statistics
  getConnectionStats() {
    return websocketService.getConnectionStats();
  }

  // Check if user is connected
  isUserConnected(userId) {
    return websocketService.isUserConnected(userId);
  }
}

// Export singleton instance
module.exports = new WebSocketHandlers();
