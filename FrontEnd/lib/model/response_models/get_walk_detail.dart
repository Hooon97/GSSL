class getWalkDetail {
  int? statusCode;
  String? message;
  Detail? detail;

  getWalkDetail({this.statusCode, this.message, this.detail});

  getWalkDetail.fromJson(Map<String, dynamic> json) {
    statusCode = json['statusCode'];
    message = json['message'];
    detail =
    json['detail'] != null ? new Detail.fromJson(json['detail']) : null;
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = new Map<String, dynamic>();
    data['statusCode'] = this.statusCode;
    data['message'] = this.message;
    if (this.detail != null) {
      data['detail'] = this.detail!.toJson();
    }
    return data;
  }
}

class Detail {
  int? walkId;
  String? startTime;
  String? endTime;
  int? distance;
  List<PetsList>? petsList;

  Detail(
      {this.walkId,
        this.startTime,
        this.endTime,
        this.distance,
        this.petsList});

  Detail.fromJson(Map<String, dynamic> json) {
    walkId = json['walk_id'];
    startTime = json['start_time'];
    endTime = json['end_time'];
    distance = json['distance'];
    if (json['petsList'] != null) {
      petsList = <PetsList>[];
      json['petsList'].forEach((v) {
        petsList!.add(new PetsList.fromJson(v));
      });
    }
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = new Map<String, dynamic>();
    data['walk_id'] = this.walkId;
    data['start_time'] = this.startTime;
    data['end_time'] = this.endTime;
    data['distance'] = this.distance;
    if (this.petsList != null) {
      data['petsList'] = this.petsList!.map((v) => v.toJson()).toList();
    }
    return data;
  }
}

class PetsList {
  int? petId;
  String? name;
  String? gender;
  String? animalPic;

  PetsList({this.petId, this.name, this.gender, this.animalPic});

  PetsList.fromJson(Map<String, dynamic> json) {
    petId = json['pet_id'];
    name = json['name'];
    gender = json['gender'];
    animalPic = json['animal_pic'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = new Map<String, dynamic>();
    data['pet_id'] = this.petId;
    data['name'] = this.name;
    data['gender'] = this.gender;
    data['animal_pic'] = this.animalPic;
    return data;
  }
}