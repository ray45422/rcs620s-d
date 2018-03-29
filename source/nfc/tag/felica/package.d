module nfc.tag.felica;
import std.stdio;
import nfc.device;
import nfc.tag.felica.felicaStandard;
import nfc.tag.felica.felicaLite;
import nfc.tag.felica.felicaLiteS;


class FeliCa{
	static FeliCa factory(ubyte[] idm, ubyte[] pmm){
		switch(checkType(pmm)){
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
	static FeliCaType checkType(ubyte[] pmm){
		if(pmm[1] <= 0x1f){
			return FeliCaType.FeliCa_STANDARD;
		}else if(pmm[1] == 0xf0){
			return FeliCaType.FeliCa_LITE;
		}else if(pmm[1] == 0xf1){
			return FeliCaType.FeliCa_LITES;
		}
		return FeliCaType.FeliCa_UNKNOWN;
	}
	static enum FeliCaType: string{
		FeliCa_UNKNOWN = "Unknown FeliCa",
		FeliCa_STANDARD = "FeliCa Standard",
		FeliCa_LITE = "FeliCa Lite",
		FeliCa_LITES = "FeliCa Lite-S"
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
		this._idm = idm;
		this._pmm = pmm;
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
		return checkType(_pmm);
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
	Device device;
	ubyte[] _idm;
	ubyte[] _pmm;
	ushort sysCode;
	ushort comSpec;
}

