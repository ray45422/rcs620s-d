module nfc.tag.felica.service;
import std.typecons;

struct Service{
	this(ushort sn, ServiceAttribute sa){
		srvNum = sn;
		srvAttr = sa;
	}
	this(ubyte[] service){
		if(service.length == 2){
			unpack(service[1] << 8 | service[0]);
		}else{
			srvNum = 0;
			srvAttr = ServiceAttribute.INVALIDE_SERVICE;
		}
	}
	this(ushort service){
		unpack(service);
	}
	ubyte[] pack(){
		ubyte[] service = new ubyte[2];
		service[0] = ((srvNum << 6) & 0b11000000) | srvAttr.attr;
		service[1] = (srvNum >>2) & 0xff;
		return service;
	}
	@property
	ushort serviceNumber(){
		return srvNum;
	}
	@property
	ServiceAttribute serviceAttribute(){
		return srvAttr;
	}
private:
	ushort srvNum;
	ServiceAttribute srvAttr;
	void unpack(ushort service){
		srvNum = (service >> 6) & 0b1111111111;
		srvAttr = attributeValueOf(service & 0b111111);
	}
}

ServiceAttribute attributeValueOf(ubyte value){
	if(value >= 0b001000 && value <= 0b010111){
		import std.conv;
		return value.to!ServiceAttribute;
	}
	return ServiceAttribute.INVALIDE_SERVICE;
}
enum ServiceAttribute: _ServiceAttribute{
	INVALIDE_SERVICE    = _ServiceAttribute(0b000000, "Invalide Service"),
	RANDOM_RW_AUTH      = _ServiceAttribute(0b001000, "Random Service Read/Write: Authentication Required"),
	RANDOM_RW_NOAUTH    = _ServiceAttribute(0b001001, "Random Service Read/Write: No Authentication Required"),
	RANDOM_R_AUTH       = _ServiceAttribute(0b001010, "Random Service Read only : Authentication Required"),
	RANDOM_R_NOAUTH     = _ServiceAttribute(0b001011, "Random Service Read only : No Authentication Required"),
	CYCLIC_RW_AUTH      = _ServiceAttribute(0b001100, "Cyclic Service Read/Write: Authentication Required"),
	CYCLIC_RW_NOAUTH    = _ServiceAttribute(0b001101, "Cyclic Service Read/Write: No Authentication Required"),
	CYCLIC_R_AUTH       = _ServiceAttribute(0b001110, "Cyclic Service Read only : Authentication Required"),
	CYCLIC_R_NOAUTH     = _ServiceAttribute(0b001111, "Cyclic Service Read only : No Authentication Required"),
	PARSE_DIRECT_AUTH   = _ServiceAttribute(0b010000, "Parse Service  Direct    : Authentication Required"),
	PARSE_DIRECT_NOAUTH = _ServiceAttribute(0b010001, "Parse Service  Direct    : No Authentication Required"),
	PARSE_CBDE_AUTH     = _ServiceAttribute(0b010010, "Parse Service  CB/DE     : Authentication Required"),
	PARSE_CBDE_NOAUTH   = _ServiceAttribute(0b010011, "Parse Service  CB/DE     : No Authentication Required"),
	PARSE_DE_AUTH       = _ServiceAttribute(0b010100, "Parse Service  Decrement : Authentication Required"),
	PARSE_DE_NOAUTH     = _ServiceAttribute(0b010101, "Parse Service  Decrement : No Authentication Required"),
	PARSE_R_AUTH        = _ServiceAttribute(0b010110, "Parse Service  Read only : Authentication Required"),
	PARSE_R_NOAUTH      = _ServiceAttribute(0b010111, "Parse Service  Read only : No Authentication Required"),
}
private struct _ServiceAttribute{
	this(ubyte attr, string desc){
		_attr = attr;
		_desc = desc;
	}
	@property
	ubyte attr(){
		return _attr;
	}
	@property
	string desc(){
		return _desc;
	}
	bool opEquals(ServiceAttribute val){
		return val.attr == _attr;
	}
	import std.traits;
	bool opEquals(T)(T val)if(isIntegral!T){
		return _attr == val;
	}
private:
	ubyte _attr;
	string _desc;
}
unittest{
	import std.stdio;
	assert(Service(1023, ServiceAttribute.PARSE_R_NOAUTH).pack() == [0xd7, 0xff]);
	assert(Service(36, ServiceAttribute.CYCLIC_R_NOAUTH).pack() == [0x0f, 0x09]);

	assert(Service(0xffd7).pack() == [0xd7, 0xff]);

	assert(Service(1023, ServiceAttribute.PARSE_R_NOAUTH).serviceAttribute == ServiceAttribute.PARSE_R_NOAUTH);
	assert(Service(1023, ServiceAttribute.PARSE_R_NOAUTH).serviceNumber == 1023);

	assert(attributeValueOf(0b001000) == ServiceAttribute.RANDOM_RW_AUTH);
	assert(attributeValueOf(0b001100) == ServiceAttribute.CYCLIC_RW_AUTH);
	assert(attributeValueOf(0b000000) == ServiceAttribute.INVALIDE_SERVICE);
	assert(attributeValueOf(0b100000) == ServiceAttribute.INVALIDE_SERVICE);

	assert(ServiceAttribute.INVALIDE_SERVICE.desc == "Invalide Service");
	assert(ServiceAttribute.PARSE_R_NOAUTH.desc == "Parse Service  Read only : No Authentication Required");
}
