import openfl.net.URLLoaderDataFormat;
import openfl.net.URLRequest;
import openfl.net.URLLoader;

import openfl.display.BitmapData;

function loadRequest(url:String, onComplete:Dynamic -> Void, ?format:URLLoaderDataFormat)
{
    final loader:URLLoader = new URLLoader();

    loader.dataFormat = format ?? URLLoaderDataFormat.TEXT;

    loader.addEventListener('complete', (e) -> {
        onComplete(loader.data);
    });

    loader.addEventListener('ioError', (e) -> debugTrace(e, 'error'));

    loader.load(new URLRequest(url));
}

final objects:Null<Int> = 50;
final columns:Int = 3;
final width:Float = FlxG.width / columns;
final height:Float = 300;
final scale:Float = 0.9;

final gamebananaUrl:String = 'https://gamebanana.com/apiv11/Mod/Index?gameId=8694' + (objects == null ? '' : '&_nPerpage=' + objects);

loadRequest(gamebananaUrl, (data) -> {
    final data = Json.parse(data)._aRecords;

    var index:Int = 0;

    for (mod in data)
    {
        final image = mod._aPreviewMedia._aImages[0];

        loadRequest(image._sBaseUrl + '/' + image._sFile, (data) -> {
            final spr:FlxSprite = new FlxSprite().loadGraphic(BitmapData.fromBytes(data));
            add(spr);

            final factor:Float = Math.min(width / spr.width, height / spr.height);

            spr.scale.x = spr.scale.y = factor * scale;
            spr.updateHitbox();

            spr.x = index % columns * width + width / 2 - spr.width / 2;
            spr.y = Math.floor(index / columns) * height + height / 2 - spr.height / 2;

            index++;
        }, URLLoaderDataFormat.BINARY);
    }
});

var camPos:Float = 0;

function onUpdate(elapsed:Float)
{
    if (Controls.MOUSE_WHEEL)
        camPos = Math.max(0, camPos - FlxG.mouse.wheel * 100);

    camGame.scroll.y = CoolUtil.fpsLerp(camGame.scroll.y, camPos, 0.3);
}