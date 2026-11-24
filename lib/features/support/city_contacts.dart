const pavlodarHotline = '+77719290003';
const karagandaAndTemirtauHotline = '+77719290005';
const astanaHotline = '+77719291001';
const supportWhatsAppNumber = '+77025834895';

class CityContact {
  const CityContact._(this.id, this.name, this.phone);

  final int id;
  final String name;
  final String phone;
}

const cityContacts = [
  CityContact._(1, 'Павлодар', pavlodarHotline),
  CityContact._(2, 'Караганда', karagandaAndTemirtauHotline),
  CityContact._(3, 'Астана', astanaHotline),
  CityContact._(4, 'Темиртау', karagandaAndTemirtauHotline),
];

CityContact? cityContactById(int? cityId) {
  for (final contact in cityContacts) {
    if (contact.id == cityId) return contact;
  }
  return null;
}

CityContact? cityContactByName(String? name) {
  for (final contact in cityContacts) {
    if (contact.name == name) return contact;
  }
  return null;
}
