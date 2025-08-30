class AppUser {
  AppUser({
    this.id,
    this.name,
    this.firstName,
    this.lastName,
    this.uniqueId,
    this.apparatusType,
    this.station,
    this.department,
  });

  AppUser.fromJson(Map<String, dynamic> json) {
    id = json['id'] as int?;
    name = json['name'] as String?;
    firstName = json['firstName'] as String?;
    lastName = json['lastName'] as String?;
    uniqueId = json['uniqueId'] as String?;
    apparatusType = json['apparatusType'] != null
        ? ApparatusType.fromJson(json['apparatusType'] as Map<String, dynamic>)
        : null;
    station = json['station'] != null
        ? UserStation.fromJson(json['station'] as Map<String, dynamic>)
        : null;
    department = json['department'] != null
        ? UserDepartment.fromJson(json['department'] as Map<String, dynamic>)
        : null;
  }

  int? id;
  String? name;
  String? firstName;
  String? lastName;
  String? uniqueId;
  ApparatusType? apparatusType;
  UserStation? station;
  UserDepartment? department;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'firstName': firstName,
      'uniqueId': uniqueId,
      'apparatusType': apparatusType?.toJson(),
      'station': station?.toJson(),
      'department': department?.toJson(),
    };
  }
}

class ApparatusType {
  ApparatusType({
    this.id,
    this.name,
  });

  ApparatusType.fromJson(Map<String, dynamic> json) {
    id = json['id'] as int?;
    name = json['name'] as String?;
  }

  int? id;
  String? name;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
    };
  }
}

class UserStation {
  UserStation({
    this.id,
    this.name,
  });

  UserStation.fromJson(Map<String, dynamic> json) {
    id = json['id'] as int?;
    name = json['name'] as String?;
  }

  int? id;
  String? name;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
    };
  }
}

class UserDepartment {
  UserDepartment({
    this.id,
    this.name,
  });

  UserDepartment.fromJson(Map<String, dynamic> json) {
    id = json['id'] as int?;
    name = json['name'] as String?;
  }

  int? id;
  String? name;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
    };
  }
}
