module nfc.tag.felica;
import std.stdio;
import std.conv;
import nfc.device;
public import nfc.tag.felica.product;
public import nfc.tag.felica.felicaStandard;
public import nfc.tag.felica.felicaLite;
public import nfc.tag.felica.felicaLiteS;

class FeliCa{
	static FeliCa factory(ubyte[] idm, ubyte[] pmm){
		switch(getProduct(pmm[1]).type){
			case FeliCaType.FeliCa_STANDARD:
				return new FeliCaStandard(idm, pmm);
			case FeliCaType.FeliCa_LITE:
				return new FeliCaLite(idm, pmm);
			case FeliCaType.FeliCa_LITES:
				return new FeliCaLiteS(idm, pmm);
			case FeliCaType.FeliCa_UNKNOWN:
			default:
				return new FeliCa(idm, pmm);
		}
	}
	static FeliCa factory(ubyte[] idm, ubyte[] pmm, Device dev){
		switch(getProduct(pmm[1]).type){
			case FeliCaType.FeliCa_STANDARD:
				return new FeliCaStandard(idm, pmm, dev);
			case FeliCaType.FeliCa_LITE:
				return new FeliCaLite(idm, pmm, dev);
			case FeliCaType.FeliCa_LITES:
				return new FeliCaLiteS(idm, pmm, dev);
			case FeliCaType.FeliCa_UNKNOWN:
			default:
				return new FeliCa(idm, pmm, dev);
		}
	}
	static enum CommunicationSpeed{
		F_212K        = 0b00000001,
		F_424K        = 0b00000010,
		F_848K        = 0b00000100, //reserved
		F_1600K       = 0b00001000, //reserved
		F_AUTO_DETECT = 0b10000000
	}
	static immutable string[] CommunicationSpeedString = [
		0b00000001: "212kbps",
		0b00000010: "424kbps",
		0b00000100: "848kbps(reserved)",
		0b00001000: "1.6Mbps(reserved)",
		0b10000000: "auto detect"
	];
	this(ubyte[] idm, ubyte[] pmm){
		this(idm, pmm, getProduct(pmm[1]));
	}
	this(ubyte[] idm, ubyte[] pmm, Device dev){
		this(idm, pmm, getProduct(pmm[1]), dev);
	}
	this(ubyte[] idm, ubyte[] pmm, ICProduct product){
		this._idm = idm;
		this._pmm = pmm;
		this._product = product;
	}
	this(ubyte[] idm, ubyte[] pmm, ICProduct product, Device dev){
		this(idm, pmm, product);
		this._dev = dev;
	}
	ubyte[] command(ubyte[] data, uint timeOut = 400){
		return _dev.cardCommand(data, timeOut);
	}
	void setSystemCode(ubyte[] systemCode){
		sysCode = systemCode[0] << 8 | systemCode[1];
	}
	void setSystemCode(ushort systemCode){
		sysCode = systemCode;
	}
	void setCommunicationSpec(ubyte[] communicationSpec){
		comSpec = communicationSpec[0] << 8 | communicationSpec[1];
	}
	void setCommunicationSpec(ushort communicationSpec){
		comSpec = communicationSpec;
	}
	FeliCaType type(){
		return _product.type;
	}
	ICProduct product(){
		return _product;
	}
	@property
	ubyte[] idm(){
		return _idm;
	}
	@property
	ubyte[] pmm(){
		return _pmm;
	}
	@property
	ushort systemCode(){
		return sysCode;
	}
	ushort communicationSpec(){
		return comSpec;
	}
	bool communicationSpec(CommunicationSpeed spec){
		if((comSpec & spec) > 0){
			return true;
		}
		return false;
	}
	override string toString(){
		return type;
	}
private:
	Device _dev;
	ICProduct _product;
	ubyte[] _idm;
	ubyte[] _pmm;
	ushort sysCode;
	ushort comSpec;
}

unittest{
	assert(getProduct(0xff).type == FeliCaType.FeliCa_UNKNOWN);
}
