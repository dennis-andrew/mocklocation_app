enum CoordinateType {
  apparatus,
  personnel,
}

enum SocketRoomAction {
  JoinApparatus('join:apparatus'),
  LeaveApparatus('leave:apparatus'),
  JoinPersonnel('join:personnel'),
  LeavePersonnel('leave:personnel');

  const SocketRoomAction(this.value);
  final String value;
}

enum SocketActionName {
  ApparatusUpdate('apparatus:update'),
  ApparatusCoordsUpdate('apparatus:coords:update'),
  PersonnelUpdate('personnel:update'),
  PersonnelCoordsUpdate('personnel:coords:update');

  const SocketActionName(this.value);
  final String value;
}
