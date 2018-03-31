module nfc.tag.felica.felicaLiteS;
import nfc.tag.felica;

class FeliCaLiteS: FeliCa{
	enum Products: ICProduct{
		RC_S966 = ICProduct([0xf1], FeliCaType.FeliCa_LITES, "RC-S966")
	}
	this(ubyte[] idm, ubyte[] ppm){
		super(idm, ppm);
	}
}
