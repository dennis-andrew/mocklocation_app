class Token {
  Token({
    this.accessToken,
    this.tokenType,
    this.refreshToken,
    this.expiresIn,
    this.createdAt,
  });

  Token.fromJson(Map<String, dynamic> json) {
    accessToken = json['accessToken'] as String?;
    tokenType = json['tokenType'] as String?;
    expiresIn = json['expiresIn'] as int?;
    refreshToken = json['refreshToken'] as String?;
    createdAt = json['createdAt'] as String?;
  }

  String? accessToken;
  String? tokenType;
  int? expiresIn;
  String? refreshToken;
  String? createdAt;

  Map<String, dynamic> toJson() {
    return {
      'accessToken': accessToken,
      'tokenType': tokenType,
      'expiresIn': expiresIn,
      'refreshToken': refreshToken,
      'createdAt': createdAt,
    };
  }
}