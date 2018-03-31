module nfc.tag.felica.felicaStandard;
import nfc.tag.felica;

class FeliCaStandard: FeliCa{
	enum Products: ICProduct{
		RC_S915 = ICProduct([0x01], FeliCaType.FeliCa_STANDARD, "RC-S915"),
		RC_S952 = ICProduct([0x08], FeliCaType.FeliCa_STANDARD, "RC-S925"),
		RC_S953 = ICProduct([0x09], FeliCaType.FeliCa_STANDARD, "RC-S953"),
		RC_S_ = ICProduct([0x0b], FeliCaType.FeliCa_STANDARD, "RC-S???(Suica etc...)"),
		RC_S960 =ICProduct([0x0d], FeliCaType.FeliCa_STANDARD, "RC-S960"),
		RC_S962 = ICProduct([0x20], FeliCaType.FeliCa_STANDARD, "RC-S962"),
		RC_SA00_1 = ICProduct([0x32], FeliCaType.FeliCa_STANDARD,"RC-SA00/1"),
		MOVILE_V1 = ICProduct([0x06, 0x07], FeliCaType.FeliCa_STANDARD, "Movile FeliCa Version1.0"),
		MOVILE_V2 = ICProduct([0x10, 0x11, 0x12, 0x13], FeliCaType.FeliCa_STANDARD, "Movile FeliCa Version2.0"),
		MOVILE_V3 = ICProduct([0x14, 0x15, 0x16, 0x17, 0x18, 0x19, 0x1a, 0x1b, 0x1c, 0x1d, 0x1e, 0x1f], FeliCaType.FeliCa_STANDARD, "Movile FeliCa Version3.0"),
		RC_S__ = ICProduct([0x36], FeliCaType.FeliCa_STANDARD, "RC-S???(new ICOCA etc..)"),
	}
	this(ubyte[] idm, ubyte[] ppm){
		super(idm, ppm);
	}
}
