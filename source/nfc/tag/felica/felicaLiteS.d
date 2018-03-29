module nfc.tag.felica.felicaLiteS;
import nfc.tag.felica;

class FeliCaLiteS: FeliCa{
	this(ubyte[] idm, ubyte[] ppm){
		super(idm, ppm);
	}
}
