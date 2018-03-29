module nfc.tag.felica.felicaStandard;
import nfc.tag.felica;

class FeliCaStandard: FeliCa{
	this(ubyte[] idm, ubyte[] ppm){
		super(idm, ppm);
	}
}
