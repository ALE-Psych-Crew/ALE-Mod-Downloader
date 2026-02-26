import flixel.text.FlxText.FlxTextBorderStyle;
import api.MobileAPI;
import haxe.Http;
import haxe.io.Bytes;
import haxe.zip.Reader;

using StringTools;

final GAME_ID:Int = 8694;
final CATEGORY_ID:Int = 3827;
final PER_PAGE:Int = 12;

final GRID_COLS:Int = 3;
final GRID_ROWS:Int = 2;
final GRID_VISIBLE:Int = GRID_COLS * GRID_ROWS;
final THUMB_BUFFER_ABOVE:Int = 3;
final THUMB_BUFFER_BELOW:Int = 3;
final THUMB_INITIAL_PREFETCH:Int = 9;

final THUMB_W:Int = 300;
final THUMB_H:Int = 169;
final THUMB_LABEL_H:Int = 44;
final GRID_START_Y:Int = 84;
final GRID_GAP_X:Int = 20;
final GRID_GAP_Y:Int = 26;
final INFO_START_Y:Int = GRID_START_Y + GRID_ROWS * (THUMB_H + THUMB_LABEL_H + GRID_GAP_Y) - GRID_GAP_Y + 6;

final TMP_DIR_NAME:String = '_moddownloader_tmp';

final MOD_MARKERS:Array<String> = [
    'data',
    'images',
    'songs',
    'scripts',
    'weeks',
    'music',
    'sounds',
    'stages',
    'characters',
    'events',
    'fonts',
    'shaders',
    'noteTypes'
];

final LEGACY_PSYCH_MARKERS:Array<String> = [
    'custom_events',
    'custom_notetypes',
    'custom_chars'
];

final ALE_STRICT_MARKERS:Array<String> = [
    'data/data.json',
    'scripts/states/',
    'scripts/substates/',
    'scripts/states/menus/'
];

var page:Int = 1;
var selected:Int = 0;
var scrollOffset:Int = 0;
var mods:Array<Dynamic> = [];

var query:String = '';
var typingSearch:Bool = false;

var loadingList:Bool = false;
var downloading:Bool = false;
var pendingInitialLoad:Bool = true;
var lastNetworkError:String = '';

var detailOpen:Bool = false;
var detailMod:Dynamic = null;

var titleText:FlxText;
var queryText:FlxText;
var statusText:FlxText;
var helpText:FlxText;
var pageText:FlxText;

var thumbCards:Array<FlxSprite> = [];
var thumbBorders:Array<FlxSprite> = [];
var thumbLabelBGs:Array<FlxSprite> = [];
var thumbPlaceholders:Array<FlxText> = [];
var thumbLabels:Array<FlxText> = [];
var thumbIds:Array<Int> = [];

var overlay:FlxSprite;
var detailBox:FlxSprite;
var detailTitle:FlxText;
var detailThumb:FlxSprite;
var detailThumbFallback:FlxText;
var detailDesc:FlxText;
var btnDownload:FlxSprite;
var btnOpenPage:FlxSprite;
var btnClose:FlxSprite;
var btnDownloadText:FlxText;
var btnOpenText:FlxText;
var btnCloseText:FlxText;

var thumbAttempted:StringMap<Bool> = new StringMap<Bool>();

var bgDownloadActive:Bool = false;
var bgDownloadUrl:String = '';
var bgDownloadPartPath:String = '';
var bgDownloadZipPath:String = '';
var bgDownloadDonePath:String = '';
var bgDownloadErrPath:String = '';
var bgDownloadModName:String = '';
var bgDownloadProfileUrl:String = '';
var bgDownloadRemoteName:String = '';

var thumbQueue:Array<Dynamic> = [];
var thumbQueueReadIndex:Int = 0;
var thumbDownloadActive:Bool = false;
var thumbDownloadOutPath:String = '';
var thumbDownloadDonePath:String = '';
var thumbDownloadErrPath:String = '';
var thumbDownloadId:String = '';

var backspaceHeld:Bool = false;

var listFetchActive:Bool = false;
var listFetchOutPath:String = '';
var listFetchDonePath:String = '';
var listFetchErrPath:String = '';

var detailFetchActive:Bool = false;
var detailFetchOutPath:String = '';
var detailFetchDonePath:String = '';
var detailFetchErrPath:String = '';
var detailFetchModId:Int = -1;

var config:Dynamic = {
    developerMode: true,
    strictAleDetection: true,
    allowLegacyPsychMods: false,
    deleteTempOnExit: true,
    deleteCacheOnExit: true
};

var categoryUrl:String = 'https://gamebanana.com/mods/cats/' + CATEGORY_ID;

function new()
{
    FlxG.mouse.visible = true;
}

var bg:FlxSprite = new FlxSprite().loadGraphic(Paths.image('ui/menuBG'));
add(bg);
bg.scrollFactor.set();
bg.color = FlxColor.fromRGB(55, 50, 70);
bg.scale.x = bg.scale.y = 1.125;

var headerBar:FlxSprite = new FlxSprite(18, 34).makeGraphic(FlxG.width - 36, 34, FlxColor.BLACK);
headerBar.alpha = 0.45;
add(headerBar);

queryText = new FlxText(34, 40, FlxG.width - 68, 'Search: [ALL]');
queryText.setFormat(Paths.font('vcr.ttf'), 20, FlxColor.fromRGB(255, 245, 125), 'left', FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
queryText.borderSize = 1;
add(queryText);

pageText = new FlxText(0, 40, FlxG.width - 34, '');
pageText.setFormat(Paths.font('vcr.ttf'), 20, FlxColor.fromRGB(125, 240, 255), 'right', FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
pageText.borderSize = 1;
add(pageText);

var gridWidth:Float = GRID_COLS * THUMB_W + (GRID_COLS - 1) * GRID_GAP_X;
var gridStartX:Float = FlxG.width * 0.5 - gridWidth * 0.5;

var buildIndex:Int = 0;
while (buildIndex < GRID_VISIBLE)
{
    var i:Int = buildIndex;
    var cx:Int = i % GRID_COLS;
    var cy:Int = Std.int(i / GRID_COLS);
    var x:Float = gridStartX + cx * (THUMB_W + GRID_GAP_X);
    var y:Float = GRID_START_Y + cy * (THUMB_H + THUMB_LABEL_H + GRID_GAP_Y);

    var border:FlxSprite = new FlxSprite(x - 2, y - 2).makeGraphic(THUMB_W + 4, THUMB_H + 4, FlxColor.fromRGB(45, 45, 55));
    add(border);
    thumbBorders.push(border);

    var card:FlxSprite = new FlxSprite(x, y).makeGraphic(THUMB_W, THUMB_H, FlxColor.fromRGB(35, 35, 45));
    add(card);
    thumbCards.push(card);

    var fallback:FlxText = new FlxText(x, y + THUMB_H * 0.5 - 14, THUMB_W, 'Preview loading...');
    fallback.setFormat(Paths.font('vcr.ttf'), 18, FlxColor.fromRGB(185, 195, 215), 'center', FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
    fallback.borderSize = 1;
    fallback.alpha = 0.95;
    add(fallback);
    thumbPlaceholders.push(fallback);

    var labelBG:FlxSprite = new FlxSprite(x, y + THUMB_H + 4).makeGraphic(THUMB_W, THUMB_LABEL_H, FlxColor.BLACK);
    labelBG.alpha = 0.5;
    add(labelBG);
    thumbLabelBGs.push(labelBG);

    var label:FlxText = new FlxText(x + 8, y + THUMB_H + 8, THUMB_W - 16, '');
    label.setFormat(Paths.font('vcr.ttf'), 15, FlxColor.WHITE, 'left', FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
    label.borderSize = 1;
    label.fieldHeight = THUMB_LABEL_H - 4;
    add(label);
    thumbLabels.push(label);

    thumbIds.push(-1);

    buildIndex++;
}

statusText = new FlxText(34, INFO_START_Y + 8, FlxG.width - 68, '');
statusText.setFormat(Paths.font('vcr.ttf'), 18, FlxColor.CYAN, 'left', FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
statusText.borderSize = 1;

var statusBG:FlxSprite = new FlxSprite(18, INFO_START_Y).makeGraphic(FlxG.width - 36, 40, FlxColor.BLACK);
statusBG.alpha = 0.45;
add(statusBG);
add(statusText);

helpText = new FlxText(34, INFO_START_Y + 50, FlxG.width - 68,
    '[Mouse Wheel] Scroll  [Click Thumb] Details  [UP/DOWN] Select  [LEFT/RIGHT] Page\n' +
    '[T] Search  [R] Reload  [C] Category Page  [ESC] Back'
);
helpText.setFormat(Paths.font('vcr.ttf'), 16, FlxColor.WHITE, 'left', FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
helpText.borderSize = 1;
helpText.alpha = 0.85;

var helpBG:FlxSprite = new FlxSprite(18, INFO_START_Y + 44).makeGraphic(FlxG.width - 36, 62, FlxColor.BLACK);
helpBG.alpha = 0.42;
add(helpBG);
add(helpText);

overlay = new FlxSprite(0, 0).makeGraphic(FlxG.width, FlxG.height, FlxColor.fromRGB(0, 0, 0));
overlay.alpha = 0.65;
overlay.visible = false;
add(overlay);

detailBox = new FlxSprite(FlxG.width * 0.12, FlxG.height * 0.1).makeGraphic(Std.int(FlxG.width * 0.76), Std.int(FlxG.height * 0.74), FlxColor.fromRGB(25, 27, 34));
detailBox.visible = false;
add(detailBox);

detailTitle = new FlxText(detailBox.x + 24, detailBox.y + 20, detailBox.width - 48, '');
detailTitle.setFormat(Paths.font('vcr.ttf'), 28, FlxColor.WHITE, 'left', FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
detailTitle.borderSize = 1;
detailTitle.visible = false;
add(detailTitle);

detailThumb = new FlxSprite(detailBox.x + 24, detailBox.y + 84).makeGraphic(400, 225, FlxColor.fromRGB(35, 35, 45));
detailThumb.visible = false;
add(detailThumb);

detailThumbFallback = new FlxText(detailThumb.x, detailThumb.y + detailThumb.height * 0.5 - 14, detailThumb.width, 'Preview loading...');
detailThumbFallback.setFormat(Paths.font('vcr.ttf'), 22, FlxColor.fromRGB(185, 195, 215), 'center', FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
detailThumbFallback.borderSize = 1;
detailThumbFallback.visible = false;
add(detailThumbFallback);

detailDesc = new FlxText(detailBox.x + 442, detailBox.y + 84, detailBox.width - 466, '');
detailDesc.setFormat(Paths.font('vcr.ttf'), 20, FlxColor.WHITE, 'left', FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
detailDesc.borderSize = 1;
detailDesc.visible = false;
add(detailDesc);

    btnDownload = new FlxSprite(detailBox.x + 26, detailBox.y + detailBox.height - 74).makeGraphic(220, 44, FlxColor.fromRGB(54, 114, 63));
    btnDownload.visible = false;
    add(btnDownload);
btnDownloadText = new FlxText(btnDownload.x, btnDownload.y + 10, btnDownload.width, 'DOWNLOAD');
btnDownloadText.setFormat(Paths.font('vcr.ttf'), 20, FlxColor.WHITE, 'center', FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
btnDownloadText.borderSize = 1;
btnDownloadText.visible = false;
add(btnDownloadText);

    btnOpenPage = new FlxSprite(btnDownload.x + 244, btnDownload.y).makeGraphic(260, 44, FlxColor.fromRGB(56, 79, 123));
    btnOpenPage.visible = false;
    add(btnOpenPage);
btnOpenText = new FlxText(btnOpenPage.x, btnOpenPage.y + 10, btnOpenPage.width, 'OPEN PAGE');
btnOpenText.setFormat(Paths.font('vcr.ttf'), 20, FlxColor.WHITE, 'center', FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
btnOpenText.borderSize = 1;
btnOpenText.visible = false;
add(btnOpenText);

    btnClose = new FlxSprite(btnOpenPage.x + 284, btnDownload.y).makeGraphic(160, 44, FlxColor.fromRGB(122, 63, 63));
    btnClose.visible = false;
    add(btnClose);
btnCloseText = new FlxText(btnClose.x, btnClose.y + 10, btnClose.width, 'CLOSE');
btnCloseText.setFormat(Paths.font('vcr.ttf'), 20, FlxColor.WHITE, 'center', FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
btnCloseText.borderSize = 1;
btnCloseText.visible = false;
add(btnCloseText);

setupMobileButtons();

function onUpdate(elapsed:Float)
{
    if (pendingInitialLoad)
    {
        pendingInitialLoad = false;
        loadConfig();
        loadModList();
    }

    pollThumbnailDownloads();
    pollListFetch();
    pollDetailFetch();

    if (bgDownloadActive)
        pollBackgroundDownload();

    if (typingSearch)
    {
        if (Controls.ACCEPT || FlxG.keys.justPressed.ENTER)
        {
            typingSearch = false;
            backspaceHeld = false;
            page = 1;
            selected = 0;
            scrollOffset = 0;
            loadModList();
            return;
        }

        if (Controls.BACK || FlxG.keys.justPressed.ESCAPE)
        {
            typingSearch = false;
            backspaceHeld = false;
            setStatus('Search edit canceled.', FlxColor.YELLOW);
            refreshHeader();
            return;
        }

        if (FlxG.keys.pressed.BACKSPACE && !backspaceHeld && query.length > 0)
        {
            backspaceHeld = true;
            query = query.substring(0, query.length - 1);
            refreshHeader();
        }

        if (!FlxG.keys.pressed.BACKSPACE)
            backspaceHeld = false;

        captureTypingFallback();
        return;
    }

    if (detailOpen)
    {
        if (FlxG.keys.justPressed.ESCAPE || Controls.BACK)
        {
            closeDetail();
            return;
        }

        if (FlxG.mouse.justPressed)
        {
            if (FlxG.mouse.overlaps(btnClose))
            {
                closeDetail();
                return;
            }

            if (FlxG.mouse.overlaps(btnOpenPage))
            {
                if (detailMod != null)
                {
                    CoolUtil.browserLoad(Std.string(detailMod._sProfileUrl));
                    setStatus('Opened mod page in browser.', FlxColor.GREEN);
                }
                return;
            }

            if (FlxG.mouse.overlaps(btnDownload) && !downloading)
            {
                if (detailMod != null)
                    downloadMod(detailMod);
                return;
            }
        }

        if ((Controls.ACCEPT || FlxG.keys.justPressed.ENTER) && !downloading)
        {
            if (detailMod != null)
                downloadMod(detailMod);
        }

        return;
    }

    if (Controls.BACK || FlxG.keys.justPressed.ESCAPE)
    {
        if (config.deleteTempOnExit)
            cleanupTemp();
        if (config.deleteCacheOnExit)
            cleanupCache();
        CoolUtil.switchState(new CustomState(CoolVars.data.mainMenuState));
        FlxG.sound.play(Paths.sound('cancelMenu'));
        return;
    }

    if (isSearchActionPressed())
    {
        typingSearch = true;
        backspaceHeld = false;
        refreshHeader();
        setStatus('Typing mode: ENTER to search.', FlxColor.YELLOW);
        return;
    }

    if (isReloadActionPressed() && !loadingList && !downloading)
    {
        loadModList();
        return;
    }

    if (isCategoryActionPressed())
    {
        CoolUtil.browserLoad(categoryUrl);
        setStatus('Opened category page in browser.', FlxColor.GREEN);
        return;
    }

    if (!loadingList && !downloading)
    {
        if (Controls.UI_LEFT_P || FlxG.keys.justPressed.LEFT)
        {
            if (page > 1)
            {
                page--;
                selected = 0;
                scrollOffset = 0;
                loadModList();
            }
        }

        if (Controls.UI_RIGHT_P || FlxG.keys.justPressed.RIGHT)
        {
            page++;
            selected = 0;
            scrollOffset = 0;
            loadModList();
        }
    }

    if (mods.length > 0)
    {
        if ((Controls.UI_UP_P || Controls.MOUSE_WHEEL_UP) && !loadingList && !downloading)
        {
            selected--;
            if (selected < 0)
                selected = mods.length - 1;
            normalizeSelectionView();
            redrawGrid();
            FlxG.sound.play(Paths.sound('scrollMenu'));
        }

        if ((Controls.UI_DOWN_P || Controls.MOUSE_WHEEL_DOWN) && !loadingList && !downloading)
        {
            selected++;
            if (selected >= mods.length)
                selected = 0;
            normalizeSelectionView();
            redrawGrid();
            FlxG.sound.play(Paths.sound('scrollMenu'));
        }

        if (FlxG.mouse.wheel > 0 && !loadingList && !downloading)
        {
            if (scrollOffset <= 0 && page > 1)
            {
                page--;
                loadModList();
                selected = mods.length <= 0 ? 0 : mods.length - 1;
                scrollOffset = maxScrollOffset();
                normalizeSelectionView();
                redrawGrid();
            }
            else
            {
                scrollOffset -= GRID_COLS;
                if (scrollOffset < 0)
                    scrollOffset = 0;
                redrawGrid();
            }
        }

        if (FlxG.mouse.wheel < 0 && !loadingList && !downloading)
        {
            var maxOffset:Int = maxScrollOffset();
            if (scrollOffset >= maxOffset && mods.length > 0)
            {
                page++;
                loadModList();
                selected = 0;
                scrollOffset = 0;
                normalizeSelectionView();
                redrawGrid();
            }
            else
            {
                scrollOffset += GRID_COLS;
                if (scrollOffset > maxOffset)
                    scrollOffset = maxOffset;
                redrawGrid();
            }
        }

        if (FlxG.mouse.justPressed)
            handleGridClick();

        if (Controls.ACCEPT || FlxG.keys.justPressed.ENTER)
            openDetail(mods[selected]);
    }
}

function onDestroy()
{
    if (CoolVars.mobile)
        MobileAPI.destroyButtons(false);

    if (config.deleteTempOnExit)
        cleanupTemp();
    if (config.deleteCacheOnExit)
        cleanupCache();
}

function setupMobileButtons()
{
    if (!CoolVars.mobile)
        return;

    MobileAPI.destroyButtons(false);

    MobileAPI.createButtons(FlxG.width - 110, FlxG.height - 110, [
        {label: 'A', keys: ClientPrefs.controls.ui.accept}
    ], null, false);

    MobileAPI.createButtons(110, FlxG.height - 110, [
        {label: 'B', keys: ClientPrefs.controls.ui.back}
    ], null, false);

    MobileAPI.createButtons(110, FlxG.height - 260, [
        {label: 'L', keys: ClientPrefs.controls.ui.left},
        {label: 'U', keys: ClientPrefs.controls.ui.up},
        {label: 'R', keys: ClientPrefs.controls.ui.right},
        {label: 'D', keys: ClientPrefs.controls.ui.down}
    ], 88, false);

    MobileAPI.createButtons(FlxG.width - 290, FlxG.height - 200, [
        {label: 'T', keys: [flixel.input.keyboard.FlxKey.T]},
        {label: 'R', keys: [flixel.input.keyboard.FlxKey.R]},
        {label: 'C', keys: [flixel.input.keyboard.FlxKey.C]}
    ], 74, false);
}

function isSearchActionPressed():Bool
{
    return FlxG.keys.justPressed.T || Controls.anyJustPressed([flixel.input.keyboard.FlxKey.T]);
}

function isReloadActionPressed():Bool
{
    return FlxG.keys.justPressed.R || Controls.anyJustPressed([flixel.input.keyboard.FlxKey.R]);
}

function isCategoryActionPressed():Bool
{
    return FlxG.keys.justPressed.C || Controls.anyJustPressed([flixel.input.keyboard.FlxKey.C]);
}

function loadConfig()
{
    var path:String = joinPath([Paths.mods, 'moddownloader', 'data.json']);
    if (!FileSystem.exists(path))
        return;

    try
    {
        var parsed:Dynamic = Json.parse(File.getContent(path));
        if (parsed != null)
            config = parsed;
    }
    catch (e:Dynamic)
    {
        setStatus('Config parse failed, using defaults.', FlxColor.YELLOW);
    }
}

function refreshHeader()
{
    var showQuery:String = query.trim().length == 0 ? '[ALL]' : query;
    queryText.text = 'Search: ' + showQuery + (typingSearch ? '  [TYPING]' : '');
    pageText.text = 'Page ' + page + '  [' + mods.length + ' loaded]';
}

function setStatus(text:String, ?color:FlxColor)
{
    statusText.text = text;
    statusText.color = color == null ? FlxColor.CYAN : color;
}

function loadModList()
{
    loadingList = true;
    refreshHeader();
    setStatus('Loading mods...', FlxColor.CYAN);

    var url:String = '';
    if (query.trim().length > 0)
    {
        url = 'https://gamebanana.com/apiv11/Util/Search/Results'
            + '?_sSearchString=' + StringTools.urlEncode(query.trim())
            + '&_sModelName=Mod'
            + '&_sOrder=best_match'
            + '&_nPage=' + page
            + '&_nPerpage=' + PER_PAGE;
    }
    else
    {
        url = 'https://gamebanana.com/apiv11/Mod/Index'
            + '?_nPage=' + page
            + '&_nPerpage=' + PER_PAGE
            + '&_sSort=Generic_Newest'
            + '&_aFilters[Generic_Game]=' + GAME_ID
            + '&_aFilters[Generic_Category]=' + CATEGORY_ID;
    }

    if (!startBackgroundListFetch(url))
    {
        mods = [];
        redrawGrid();
        loadingList = false;
        var details:String = lastNetworkError.length > 0 ? (' | ' + lastNetworkError) : '';
        setStatus('Failed to start list request.' + details, FlxColor.RED);
        return;
    }

    setStatus('Loading mods... (network)', FlxColor.CYAN);
}

function startBackgroundListFetch(url:String):Bool
{
    lastNetworkError = '';

    var tmpRoot:String = joinPath([getDownloaderTmpRoot(), 'listjobs']);
    ensureDir(tmpRoot);

    var stamp:String = Std.string(Date.now().getTime());
    listFetchOutPath = joinPath([tmpRoot, 'list_' + stamp + '.json']);
    listFetchDonePath = listFetchOutPath + '.done';
    listFetchErrPath = listFetchOutPath + '.err';

    if (FileSystem.exists(listFetchOutPath)) FileSystem.deleteFile(listFetchOutPath);
    if (FileSystem.exists(listFetchDonePath)) FileSystem.deleteFile(listFetchDonePath);
    if (FileSystem.exists(listFetchErrPath)) FileSystem.deleteFile(listFetchErrPath);

    var requestUrl:String = url;
    var outPath:String = listFetchOutPath;
    var donePath:String = listFetchDonePath;
    var errPath:String = listFetchErrPath;

    CoolUtil.createSafeThread(function()
    {
        var res:Dynamic = httpGetTextRequest(requestUrl, 35, 'ALEPsychModDownloader/1.4', null);
        if (res.ok)
            File.saveContent(outPath, Std.string(res.data));
        else if (Std.string(res.err).length > 0)
            File.saveContent(errPath, Std.string(res.err));

        File.saveContent(donePath, res.ok ? 'OK' : 'FAIL');
    });

    listFetchActive = true;
    return true;
}

function pollListFetch()
{
    if (!listFetchActive)
        return;

    if (!FileSystem.exists(listFetchDonePath))
        return;

    listFetchActive = false;

    var doneState:String = '';
    try
    {
        doneState = File.getContent(listFetchDonePath).trim();
    }
    catch (e:Dynamic) {}

    if (doneState != 'OK' || !FileSystem.exists(listFetchOutPath))
    {
        var err:String = '';
        if (FileSystem.exists(listFetchErrPath))
        {
            try
            {
                err = trimError(File.getContent(listFetchErrPath));
            }
            catch (e:Dynamic) {}
        }

        mods = [];
        redrawGrid();
        loadingList = false;
        setStatus('Failed to fetch list.' + (err.length > 0 ? (' ' + err) : ''), FlxColor.RED);
        if (FileSystem.exists(listFetchOutPath)) FileSystem.deleteFile(listFetchOutPath);
        if (FileSystem.exists(listFetchDonePath)) FileSystem.deleteFile(listFetchDonePath);
        if (FileSystem.exists(listFetchErrPath)) FileSystem.deleteFile(listFetchErrPath);
        return;
    }

    var jsonRaw:String = '';
    try
    {
        jsonRaw = File.getContent(listFetchOutPath);
    }
    catch (e:Dynamic) {}
    applyListJson(jsonRaw);

    if (FileSystem.exists(listFetchDonePath)) FileSystem.deleteFile(listFetchDonePath);
    if (FileSystem.exists(listFetchErrPath)) FileSystem.deleteFile(listFetchErrPath);
    if (FileSystem.exists(listFetchOutPath)) FileSystem.deleteFile(listFetchOutPath);
}

function applyListJson(jsonRaw:String)
{
    if (jsonRaw == null || jsonRaw.length == 0)
    {
        mods = [];
        redrawGrid();
        loadingList = false;
        setStatus('Empty list response.', FlxColor.RED);
        return;
    }

    var data:Dynamic = null;
    try
    {
        data = Json.parse(jsonRaw);
    }
    catch (e:Dynamic)
    {
        mods = [];
        redrawGrid();
        loadingList = false;
        setStatus('Failed to parse API response.', FlxColor.RED);
        return;
    }

    var records:Array<Dynamic> = cast (data == null ? null : data._aRecords);
    if (records == null)
        records = [];

    var filtered:Array<Dynamic> = [];
    var i:Int = 0;
    while (i < records.length)
    {
        var record:Dynamic = records[i];
        if (record != null && record._sModelName == 'Mod')
        {
            var gameId:Int = -1;
            if (record._aGame != null && record._aGame._idRow != null)
                gameId = Std.int(record._aGame._idRow);

            var categoryMatch:Bool = false;
            if (record._aRootCategory != null)
            {
                var profile:String = Std.string(record._aRootCategory._sProfileUrl);
                categoryMatch = profile.contains('/mods/cats/' + CATEGORY_ID);
            }

            if (gameId == GAME_ID && categoryMatch)
                filtered[filtered.length] = record;
        }
        i++;
    }

    mods = filtered;
    selected = 0;
    scrollOffset = 0;
    thumbQueue = [];
    thumbQueueReadIndex = 0;
    thumbDownloadActive = false;

    queueInitialThumbnails();
    redrawGrid();

    loadingList = false;
    if (mods.length == 0)
        setStatus('No mods on this page.', FlxColor.YELLOW);
    else
        setStatus('Loaded ' + mods.length + ' mod(s). Click a thumbnail for details.', FlxColor.GREEN);
}

function startBackgroundDetailFetch(modId:Int):Bool
{
    if (modId <= 0)
        return false;

    if (detailFetchActive && detailFetchModId == modId)
        return true;

    var tmpRoot:String = joinPath([getDownloaderTmpRoot(), 'detailjobs']);
    ensureDir(tmpRoot);

    detailFetchModId = modId;
    detailFetchOutPath = joinPath([tmpRoot, 'detail_' + modId + '.json']);
    detailFetchDonePath = detailFetchOutPath + '.done';
    detailFetchErrPath = detailFetchOutPath + '.err';

    if (FileSystem.exists(detailFetchOutPath)) FileSystem.deleteFile(detailFetchOutPath);
    if (FileSystem.exists(detailFetchDonePath)) FileSystem.deleteFile(detailFetchDonePath);
    if (FileSystem.exists(detailFetchErrPath)) FileSystem.deleteFile(detailFetchErrPath);

    var url:String = 'https://gamebanana.com/apiv11/Mod/' + modId + '/ProfilePage';
    var pageUrl:String = 'https://gamebanana.com/mods/' + modId;
    var outPath:String = detailFetchOutPath;
    var donePath:String = detailFetchDonePath;
    var errPath:String = detailFetchErrPath;

    CoolUtil.createSafeThread(function()
    {
        var errParts:Array<String> = [];
        var apiRes:Dynamic = httpGetTextRequest(url, 35, 'ALEPsychModDownloader/1.4', null);
        if (apiRes.ok)
        {
            File.saveContent(outPath, Std.string(apiRes.data));
            File.saveContent(donePath, 'OK');
            return;
        }

        var apiErr:String = trimError(Std.string(apiRes.err));
        if (apiErr.length > 0)
            errParts.push('api: ' + apiErr);

        var htmlRes:Dynamic = httpGetTextRequest(pageUrl, 35, 'ALEPsychModDownloader/1.4', null);
        if (htmlRes.ok)
        {
            File.saveContent(outPath, Std.string(htmlRes.data));
            File.saveContent(donePath, 'OK');
            return;
        }

        var htmlErr:String = trimError(Std.string(htmlRes.err));
        if (htmlErr.length > 0)
            errParts.push('html: ' + htmlErr);

        if (errParts.length > 0)
            File.saveContent(errPath, errParts.join(' | '));
        File.saveContent(donePath, 'FAIL');
    });

    detailFetchActive = true;
    return true;
}

function pollDetailFetch()
{
    if (!detailFetchActive)
        return;

    if (!FileSystem.exists(detailFetchDonePath))
        return;

    detailFetchActive = false;

    var doneState:String = '';
    try
    {
        doneState = File.getContent(detailFetchDonePath).trim();
    }
    catch (e:Dynamic) {}

    if (doneState == 'OK' && FileSystem.exists(detailFetchOutPath))
    {
        var jsonRaw:String = '';
        try
        {
            jsonRaw = File.getContent(detailFetchOutPath);
        }
        catch (e:Dynamic) {}

        applyDetailProfileJson(detailFetchModId, jsonRaw);
    }
    else
    {
        if (detailOpen && detailMod != null && Std.int(detailMod._idRow) == detailFetchModId)
        {
            var fallbackSubline:String = readModSubline(detailMod);
            var fallbackDesc:String = readModDescription(detailMod);
            if (fallbackSubline == 'No subline available.')
                fallbackSubline = 'Subline unavailable.';
            if (fallbackDesc == 'No description available.')
                fallbackDesc = 'Description unavailable for this mod.';

            var submitter:String = detailMod._aSubmitter == null ? 'Unknown' : Std.string(detailMod._aSubmitter._sName);
            var likes:Int = detailMod._nLikeCount == null ? 0 : Std.int(detailMod._nLikeCount);
            var views:Int = detailMod._nViewCount == null ? 0 : Std.int(detailMod._nViewCount);

            detailDesc.text =
                'By ' + submitter + '\n'
                + fallbackSubline + '\n'
                + 'Likes: ' + likes + '  Views: ' + views + '\n\n'
                + fallbackDesc;
        }
    }

    if (FileSystem.exists(detailFetchOutPath)) FileSystem.deleteFile(detailFetchOutPath);
    if (FileSystem.exists(detailFetchDonePath)) FileSystem.deleteFile(detailFetchDonePath);
    if (FileSystem.exists(detailFetchErrPath)) FileSystem.deleteFile(detailFetchErrPath);
}

function applyDetailProfileJson(modId:Int, jsonRaw:String)
{
    if (jsonRaw == null || jsonRaw.length == 0)
        return;

    var record:Dynamic = null;
    var data:Dynamic = null;
    try
    {
        data = Json.parse(jsonRaw);
        record = extractDetailRecord(data);
    }
    catch (e:Dynamic)
    {
        record = extractDetailFromHtml(jsonRaw);
    }

    if (record == null)
        return;

    var i:Int = 0;
    while (i < mods.length)
    {
        var mod:Dynamic = mods[i];
        if (mod != null && Std.int(mod._idRow) == modId)
        {
            mergeDetailIntoMod(mod, record);
            break;
        }
        i++;
    }

    if (detailOpen && detailMod != null && Std.int(detailMod._idRow) == modId)
    {
        mergeDetailIntoMod(detailMod, record);
        openDetail(detailMod);
    }
}

function extractDetailRecord(data:Dynamic):Dynamic
{
    if (data == null)
        return null;
    if (data._aRecord != null)
        return data._aRecord;
    if (data._aSubmission != null)
        return data._aSubmission;
    return data;
}

function extractDetailFromHtml(html:String):Dynamic
{
    if (html == null || html.length == 0)
        return null;

    var desc:String = extractMetaContent(html, 'description');
    if (desc.length <= 0)
        desc = extractMetaProperty(html, 'og:description');

    var title:String = extractMetaProperty(html, 'og:title');

    if (desc.length <= 0 && title.length <= 0)
        return null;

    return {
        _sDescription: desc,
        _sSummary: desc,
        _sSubline: title
    };
}

function extractMetaContent(html:String, name:String):String
{
    var text:String = extractMetaFlexible(html, 'name', name);
    if (text.length > 0)
        return text;
    return '';
}

function extractMetaProperty(html:String, prop:String):String
{
    var text:String = extractMetaFlexible(html, 'property', prop);
    if (text.length > 0)
        return text;
    return '';
}

function extractMetaFlexible(html:String, attr:String, value:String):String
{
    if (html == null || html.length == 0)
        return '';

    var a:String = attr;
    var v:String = value;

    var rx1:EReg = new EReg('<meta[^>]*' + a + '=["\']' + v + '["\'][^>]*content=["\']([^"\']*)["\']', 'i');
    if (rx1.match(html))
        return sanitizeApiText(rx1.matched(1));

    var rx2:EReg = new EReg('<meta[^>]*content=["\']([^"\']*)["\'][^>]*' + a + '=["\']' + v + '["\']', 'i');
    if (rx2.match(html))
        return sanitizeApiText(rx2.matched(1));

    var rx3:EReg = new EReg('<meta[^>]*' + a + '=["\']' + v + '["\'][^>]*content=([^\s>]+)', 'i');
    if (rx3.match(html))
        return sanitizeApiText(rx3.matched(1));

    return '';
}

function mergeDetailIntoMod(target:Dynamic, source:Dynamic)
{
    if (target == null || source == null)
        return;

    var fields:Array<String> = [
        '_sDescription', '_sText', '_sBody', '_sContent', '_sSummary',
        '_sSubline', '_sSubLine', '_sSubtitle', '_sSubTitle', '_sTagline',
        '_sIconUrl', '_sImageUrl', '_sPreviewUrl', '_aPreviewMedia'
    ];

    var i:Int = 0;
    while (i < fields.length)
    {
        var key:String = fields[i];
        var value:Dynamic = Reflect.field(source, key);
        if (value != null)
            Reflect.setField(target, key, value);
        i++;
    }
}

function redrawGrid()
{
    refreshHeader();
    queueThumbnailWindow();

    var i:Int = 0;
    while (i < GRID_VISIBLE)
    {
        var idx:Int = scrollOffset + i;
        var border:FlxSprite = thumbBorders[i];
        var card:FlxSprite = thumbCards[i];
        var labelBG:FlxSprite = thumbLabelBGs[i];
        var fallback:FlxText = thumbPlaceholders[i];
        var label:FlxText = thumbLabels[i];

        if (idx >= mods.length)
        {
            card.visible = false;
            border.visible = false;
            labelBG.visible = false;
            fallback.visible = false;
            label.visible = false;
            thumbIds[i] = -1;
            i++;
            continue;
        }

        var mod:Dynamic = mods[idx];
        var modId:Int = Std.int(mod._idRow);
        thumbIds[i] = modId;

        card.visible = true;
        border.visible = true;
        labelBG.visible = true;
        fallback.visible = false;
        label.visible = true;

        var isSelected:Bool = idx == selected;
        border.color = isSelected ? FlxColor.fromRGB(170, 220, 255) : FlxColor.fromRGB(45, 45, 55);
        labelBG.alpha = isSelected ? 0.68 : 0.5;

        var name:String = Std.string(mod._sName);
        var likes:Int = mod._nLikeCount == null ? 0 : Std.int(mod._nLikeCount);
        label.text = trimText(name, 42) + '\nLikes: ' + likes;

        var thumbPath:String = ensureThumbnail(mod, false);
        if (isUsableImage(thumbPath))
        {
            if (!applySpriteImage(card, thumbPath, THUMB_W, THUMB_H))
            {
                setThumbFallbackGraphic(card);
                fallback.text = 'Preview unavailable';
                fallback.visible = true;
            }
        }
        else
        {
            setThumbFallbackGraphic(card);
            fallback.text = 'Preview loading...';
            fallback.visible = true;
        }
        i++;
    }
}

function setThumbFallbackGraphic(card:FlxSprite)
{
    card.makeGraphic(THUMB_W, THUMB_H, FlxColor.fromRGB(35, 35, 45));
    card.scale.set(1, 1);
    card.setGraphicSize(THUMB_W, THUMB_H);
    card.updateHitbox();
}

function ensureThumbnail(mod:Dynamic, allowQueue:Bool):String
{
    if (mod == null)
        return '';

    var modId:Int = Std.int(mod._idRow);
    var tmpThumbDir:String = joinPath([getDownloaderCacheRoot(), 'thumbs']);
    ensureDir(tmpThumbDir);

    var outBase:String = joinPath([tmpThumbDir, 'thumb_' + modId]);
    var knownExts:Array<String> = ['jpg', 'jpeg', 'png', 'webp'];
    var extIndex:Int = 0;
    while (extIndex < knownExts.length)
    {
        var ext:String = knownExts[extIndex];
        var existing:String = outBase + '.' + ext;
        if (FileSystem.exists(existing))
            return existing;
        extIndex++;
    }

    if (allowQueue)
        queueThumbnailForMod(mod, true);

    return '';
}

function queueInitialThumbnails()
{
    var toLoad:Int = Std.int(Math.min(THUMB_INITIAL_PREFETCH, mods.length));
    var i:Int = 0;
    while (i < toLoad)
    {
        queueThumbnailForMod(mods[i], i == 0);
        i++;
    }
}

function queueThumbnailWindow()
{
    if (mods.length <= 0)
        return;

    var start:Int = scrollOffset - THUMB_BUFFER_ABOVE;
    var ending:Int = scrollOffset + GRID_VISIBLE + THUMB_BUFFER_BELOW - 1;

    if (start < 0)
        start = 0;
    if (ending >= mods.length)
        ending = mods.length - 1;

    var i:Int = start;
    while (i <= ending)
    {
        queueThumbnailForMod(mods[i], i == selected);
        i++;
    }
}

function queueThumbnailForMod(mod:Dynamic, prioritize:Bool)
{
    if (mod == null)
        return;

    var modId:Int = Std.int(mod._idRow);
    var tmpThumbDir:String = joinPath([getDownloaderCacheRoot(), 'thumbs']);
    var outBase:String = joinPath([tmpThumbDir, 'thumb_' + modId]);
    var knownExts:Array<String> = ['jpg', 'jpeg', 'png', 'webp'];
    var extIndex:Int = 0;
    while (extIndex < knownExts.length)
    {
        var ext:String = knownExts[extIndex];
        if (FileSystem.exists(outBase + '.' + ext))
            return;
        extIndex++;
    }

    var key:String = Std.string(modId);
    if (thumbAttempted.exists(key) && thumbAttempted.get(key))
        return;

    var url:String = getThumbnailUrl(mod);
    if (url.length <= 0)
    {
        thumbAttempted.set(key, true);
        return;
    }

    var item:Dynamic = {
        id: key,
        url: url,
        outPath: outBase + '.' + guessFileExt(url)
    };

    enqueueThumb(item);

    thumbAttempted.set(key, true);
}

function getThumbnailUrl(mod:Dynamic):String
{
    if (mod == null)
        return '';

    var preview:Dynamic = mod._aPreviewMedia;
    if (preview != null)
    {
        var images:Array<Dynamic> = cast preview._aImages;
        if (images != null && images.length > 0)
        {
            var image:Dynamic = images[0];
            if (image != null)
            {
                var base:String = Std.string(image._sBaseUrl);
                if (base != null && base.length > 0)
                {
                    var file:String = Std.string(image._sFile220);
                    if (file == null || file.length == 0)
                        file = Std.string(image._sFile530);
                    if (file == null || file.length == 0)
                        file = Std.string(image._sFile100);
                    if (file == null || file.length == 0)
                        file = Std.string(image._sFile);
                    if (file != null && file.length > 0)
                        return base + '/' + file;
                }
            }
        }
    }

    var fallbackKeys:Array<String> = ['_sIconUrl', '_sImageUrl', '_sPreviewUrl', '_sLogoUrl'];
    var i:Int = 0;
    while (i < fallbackKeys.length)
    {
        var url:String = Std.string(Reflect.field(mod, fallbackKeys[i]));
        if (url != null && url.length > 8 && (url.startsWith('http://') || url.startsWith('https://')))
            return url;
        i++;
    }

    return '';
}

function pollThumbnailDownloads()
{
    if (thumbDownloadActive)
    {
        if (!FileSystem.exists(thumbDownloadDonePath))
            return;

        thumbDownloadActive = false;

        var ok:Bool = FileSystem.exists(thumbDownloadOutPath);
        if (!ok && thumbDownloadId != null && thumbDownloadId.length > 0)
            thumbAttempted.set(thumbDownloadId, false);

        if (ok)
        {
            redrawGrid();
            if (detailOpen && detailMod != null)
                openDetail(detailMod);
        }

        if (FileSystem.exists(thumbDownloadDonePath)) FileSystem.deleteFile(thumbDownloadDonePath);
        if (FileSystem.exists(thumbDownloadErrPath)) FileSystem.deleteFile(thumbDownloadErrPath);

        return;
    }

    if (thumbQueueReadIndex >= thumbQueue.length)
        return;

    var item:Dynamic = thumbQueue[thumbQueueReadIndex];
    thumbQueueReadIndex++;

    if (thumbQueueReadIndex > 64 && thumbQueueReadIndex >= thumbQueue.length)
    {
        thumbQueue = [];
        thumbQueueReadIndex = 0;
    }
    var outPath:String = Std.string(item.outPath);
    var url:String = Std.string(item.url);

    if (FileSystem.exists(outPath))
        return;

    startBackgroundThumbDownload(Std.string(item.id), url, outPath);
}

function enqueueThumb(item:Dynamic)
{
    if (item == null)
        return;
    thumbQueue[thumbQueue.length] = item;
}

function startBackgroundThumbDownload(id:String, url:String, outPath:String)
{
    var tmpRoot:String = joinPath([getDownloaderTmpRoot(), 'thumbjobs']);
    ensureDir(tmpRoot);

    thumbDownloadOutPath = outPath;
    thumbDownloadDonePath = outPath + '.done';
    thumbDownloadErrPath = outPath + '.err';
    thumbDownloadId = id;

    if (FileSystem.exists(thumbDownloadDonePath)) FileSystem.deleteFile(thumbDownloadDonePath);
    if (FileSystem.exists(thumbDownloadErrPath)) FileSystem.deleteFile(thumbDownloadErrPath);

    var requestUrl:String = url;
    var filePath:String = outPath;
    var donePath:String = thumbDownloadDonePath;
    var errPath:String = thumbDownloadErrPath;

    CoolUtil.createSafeThread(function()
    {
        var res:Dynamic = httpDownloadToFileRequest(requestUrl, filePath, 40, 'ALEPsychModDownloader/1.3', 'https://gamebanana.com/');
        if (!res.ok && Std.string(res.err).length > 0)
            File.saveContent(errPath, Std.string(res.err));

        File.saveContent(donePath, res.ok ? 'OK' : 'FAIL');
    });

    thumbDownloadActive = true;
}

function guessFileExt(url:String):String
{
    if (url == null || url.length == 0)
        return 'jpg';

    var clean:String = url;
    var q:Int = clean.indexOf('?');
    if (q >= 0)
        clean = clean.substring(0, q);

    var dot:Int = clean.lastIndexOf('.');
    if (dot < 0 || dot >= clean.length - 1)
        return 'jpg';

    var ext:String = clean.substring(dot + 1).toLowerCase();
    if (ext == 'jpeg' || ext == 'jpg' || ext == 'png' || ext == 'webp')
        return ext;
    return 'jpg';
}

function maxScrollOffset():Int
{
    if (mods.length <= GRID_VISIBLE)
        return 0;

    var maxStart:Int = mods.length - GRID_VISIBLE;
    var snapped:Int = Std.int(Math.ceil(maxStart / GRID_COLS)) * GRID_COLS;
    return snapped;
}

function normalizeSelectionView()
{
    if (selected < scrollOffset)
        scrollOffset = Std.int(selected / GRID_COLS) * GRID_COLS;

    var lastVisible:Int = scrollOffset + GRID_VISIBLE - 1;
    if (selected > lastVisible)
    {
        var rowStart:Int = Std.int(selected / GRID_COLS) * GRID_COLS;
        scrollOffset = rowStart - (GRID_ROWS - 1) * GRID_COLS;
    }

    if (scrollOffset < 0)
        scrollOffset = 0;

    var maxOffset:Int = maxScrollOffset();
    if (scrollOffset > maxOffset)
        scrollOffset = maxOffset;
}

function handleGridClick()
{
    var i:Int = 0;
    while (i < GRID_VISIBLE)
    {
        var idx:Int = scrollOffset + i;
        if (idx >= mods.length)
        {
            i++;
            continue;
        }

        if (FlxG.mouse.overlaps(thumbCards[i]) || FlxG.mouse.overlaps(thumbLabels[i]))
        {
            selected = idx;
            redrawGrid();
            openDetail(mods[idx]);
            return;
        }

        i++;
    }
}

function openDetail(mod:Dynamic)
{
    detailMod = mod;
    detailOpen = true;
    setDetailVisible(true);

    var name:String = Std.string(mod._sName);
    var likes:Int = mod._nLikeCount == null ? 0 : Std.int(mod._nLikeCount);
    var views:Int = mod._nViewCount == null ? 0 : Std.int(mod._nViewCount);
    var submitter:String = mod._aSubmitter == null ? 'Unknown' : Std.string(mod._aSubmitter._sName);
    var subline:String = readModSubline(mod);
    var description:String = readModDescription(mod);
    var missingMeta:Bool = subline == 'No subline available.' || description == 'No description available.';

    detailTitle.text = name;
    detailDesc.text =
        'By ' + submitter + '\n'
        + subline + '\n'
        + 'Likes: ' + likes + '  Views: ' + views + '\n\n'
        + description;

    if (missingMeta)
    {
        var modId:Int = Std.int(mod._idRow);
        var started:Bool = startBackgroundDetailFetch(modId);
        if (started)
            detailDesc.text =
                'By ' + submitter + '\n'
                + subline + '\n'
                + 'Likes: ' + likes + '  Views: ' + views + '\n\n'
                + 'Loading description...';
    }

    var thumbPath:String = ensureThumbnail(mod, true);
    detailThumbFallback.visible = false;
    if (isUsableImage(thumbPath))
    {
        if (!applySpriteImage(detailThumb, thumbPath, 400, 225))
        {
            setDetailFallbackGraphic();
            detailThumbFallback.text = 'Preview unavailable';
            detailThumbFallback.visible = true;
        }
    }
    else
    {
        setDetailFallbackGraphic();
        detailThumbFallback.text = 'Preview loading...';
        detailThumbFallback.visible = true;
    }
}

function setDetailFallbackGraphic()
{
    detailThumb.makeGraphic(400, 225, FlxColor.fromRGB(35, 35, 45));
    detailThumb.scale.set(1, 1);
    detailThumb.setGraphicSize(400, 225);
    detailThumb.updateHitbox();
    detailThumbFallback.x = detailThumb.x;
    detailThumbFallback.y = detailThumb.y + detailThumb.height * 0.5 - 14;
    detailThumbFallback.width = detailThumb.width;
}

function readModSubline(mod:Dynamic):String
{
    if (mod == null)
        return 'No subline available.';

    var keys:Array<String> = [
        '_sSubline',
        '_sSubLine',
        '_sSubtitle',
        '_sSubTitle',
        '_sTagline',
        '_sSummary'
    ];

    for (key in keys)
    {
        var value:Dynamic = Reflect.field(mod, key);
        var text:String = sanitizeApiText(Std.string(value));
        if (text.length > 0 && text != 'null')
            return text;
    }

    return 'No subline available.';
}

function readModDescription(mod:Dynamic):String
{
    if (mod == null)
        return 'No description available.';

    var keys:Array<String> = [
        '_sDescription',
        '_sText',
        '_sBody',
        '_sContent',
        '_sSummary'
    ];

    for (key in keys)
    {
        var value:Dynamic = Reflect.field(mod, key);
        var text:String = sanitizeApiText(Std.string(value));
        if (text.length > 0 && text != 'null')
            return trimText(text, 500);
    }

    return 'No description available.';
}

function sanitizeApiText(text:String):String
{
    if (text == null)
        return '';

    var t:String = text;
    var html:EReg = ~/<[^>]*>/g;
    t = html.replace(t, ' ');
    t = t.replace('&nbsp;', ' ').replace('&amp;', '&').replace('&quot;', '"').replace('&#39;', "'");
    t = t.replace('\r', ' ').replace('\n', ' ').trim();

    while (t.contains('  '))
        t = t.replace('  ', ' ');

    return t;
}

function closeDetail()
{
    detailOpen = false;
    detailMod = null;
    setDetailVisible(false);
}

function setDetailVisible(visible:Bool)
{
    overlay.visible = visible;
    detailBox.visible = visible;
    detailTitle.visible = visible;
    detailThumb.visible = visible;
    if (!visible)
        detailThumbFallback.visible = false;
    detailDesc.visible = visible;
    btnDownload.visible = visible;
    btnOpenPage.visible = visible;
    btnClose.visible = visible;
    btnDownloadText.visible = visible;
    btnOpenText.visible = visible;
    btnCloseText.visible = visible;
}

function downloadMod(mod:Dynamic)
{
    if (mod == null)
        return;

    downloading = true;

    var modId:Int = Std.int(mod._idRow);
    var modName:String = Std.string(mod._sName);
    var profileUrl:String = Std.string(mod._sProfileUrl);

    setStatus('Step 1/5: Fetching download options...', FlxColor.CYAN);
    var dlRaw:String = networkGetText('https://gamebanana.com/apiv11/Mod/' + modId + '/DownloadPage');
    if (dlRaw == null || dlRaw.length == 0)
    {
        downloading = false;
        setStatus('Could not fetch download options. ' + lastNetworkError, FlxColor.RED);
        return;
    }

    var dlData:Dynamic = null;
    try
    {
        dlData = Json.parse(dlRaw);
    }
    catch (e:Dynamic)
    {
        downloading = false;
        setStatus('Download API parse failed.', FlxColor.RED);
        return;
    }

    var files:Array<Dynamic> = cast (dlData == null ? null : dlData._aFiles);
    if (files == null || files.length == 0)
    {
        downloading = false;
        setStatus('No downloadable files were found.', FlxColor.RED);
        return;
    }

    var best:Dynamic = pickBestDownload(files);
    if (best == null)
    {
        downloading = false;
        setStatus('No supported ZIP file found.', FlxColor.RED);
        return;
    }

    var fileId:Int = Std.int(best._idRow);
    var downloadUrl:String = Std.string(best._sDownloadUrl);

    setStatus('Step 2/5: Inspecting file list...', FlxColor.CYAN);
    var rawList:String = networkGetText('https://gamebanana.com/apiv11/File/' + fileId + '/RawFileList');
    if (!isLikelyAleFromRawList(rawList))
    {
        downloading = false;
        setStatus('This file does not look like ALE Psych structure (raw list check).', FlxColor.RED);
        return;
    }

    var tmpRoot:String = getDownloaderTmpRoot();
    ensureDir(tmpRoot);

    var zipPath:String = joinPath([tmpRoot, 'mod_' + modId + '.zip']);
    bgDownloadModName = modName;
    bgDownloadProfileUrl = profileUrl;
    bgDownloadRemoteName = Std.string(best._sFile);

    if (!startBackgroundDownload(downloadUrl, zipPath))
    {
        downloading = false;
        setStatus('Download start failed. ' + lastNetworkError, FlxColor.RED);
        return;
    }

    setStatus('Step 3/5: Downloading archive... 0 B', FlxColor.CYAN);
}

function startBackgroundDownload(url:String, zipPath:String):Bool
{
    lastNetworkError = '';

    bgDownloadUrl = url;
    bgDownloadZipPath = zipPath;
    bgDownloadPartPath = zipPath + '.part';
    bgDownloadDonePath = zipPath + '.done';
    bgDownloadErrPath = zipPath + '.err';

    if (FileSystem.exists(bgDownloadPartPath)) FileSystem.deleteFile(bgDownloadPartPath);
    if (FileSystem.exists(bgDownloadDonePath)) FileSystem.deleteFile(bgDownloadDonePath);
    if (FileSystem.exists(bgDownloadErrPath)) FileSystem.deleteFile(bgDownloadErrPath);
    if (FileSystem.exists(bgDownloadZipPath)) FileSystem.deleteFile(bgDownloadZipPath);

    var requestUrl:String = bgDownloadUrl;
    var partPath:String = bgDownloadPartPath;
    var zipOutPath:String = bgDownloadZipPath;
    var donePath:String = bgDownloadDonePath;
    var errPath:String = bgDownloadErrPath;

    CoolUtil.createSafeThread(function()
    {
        var res:Dynamic = httpDownloadToFileRequest(requestUrl, partPath, 180, 'ALEPsychModDownloader/1.2', 'https://gamebanana.com/');
        var ok:Bool = res.ok;
        var errText:String = trimError(Std.string(res.err));

        if (ok)
            ok = moveFile(partPath, zipOutPath);

        if (!ok && errText.length > 0)
            File.saveContent(errPath, errText);

        File.saveContent(donePath, ok ? 'OK' : 'FAIL');
    });

    bgDownloadActive = true;
    return true;
}

function pollBackgroundDownload()
{
    if (!bgDownloadActive)
        return;

    var sizeLabel:String = '0 B';
    if (FileSystem.exists(bgDownloadPartPath))
    {
        try
        {
            var stat = FileSystem.stat(bgDownloadPartPath);
            sizeLabel = formatBytes(stat.size);
        }
        catch (e:Dynamic) {}
    }

    if (!FileSystem.exists(bgDownloadDonePath))
    {
        setStatus('Step 3/5: Downloading archive... ' + sizeLabel, FlxColor.CYAN);
        return;
    }

    bgDownloadActive = false;

    var doneState:String = '';
    try
    {
        doneState = File.getContent(bgDownloadDonePath).trim();
    }
    catch (e:Dynamic) {}

    if (doneState != 'OK' || !FileSystem.exists(bgDownloadZipPath))
    {
        var err:String = '';
        if (FileSystem.exists(bgDownloadErrPath))
        {
            try
            {
                err = trimError(File.getContent(bgDownloadErrPath));
            }
            catch (e:Dynamic) {}
        }

        downloading = false;
        if (FileSystem.exists(bgDownloadDonePath)) FileSystem.deleteFile(bgDownloadDonePath);
        if (FileSystem.exists(bgDownloadErrPath)) FileSystem.deleteFile(bgDownloadErrPath);
        setStatus('Download failed.' + (err.length > 0 ? (' ' + err) : ''), FlxColor.RED);
        return;
    }

    setStatus('Step 4/5: Extracting and scanning...', FlxColor.CYAN);
    var result:Dynamic = installArchiveFromFile(bgDownloadZipPath, bgDownloadModName, bgDownloadProfileUrl, bgDownloadRemoteName);

    setStatus('Step 5/5: Finalizing...', FlxColor.CYAN);
    cleanupTemp();

    if (FileSystem.exists(bgDownloadDonePath)) FileSystem.deleteFile(bgDownloadDonePath);
    if (FileSystem.exists(bgDownloadErrPath)) FileSystem.deleteFile(bgDownloadErrPath);

    downloading = false;
    if (result.success)
        setStatus(Std.string(result.message), FlxColor.GREEN);
    else
        setStatus(Std.string(result.message), FlxColor.RED);
}

function formatBytes(size:Float):String
{
    if (size < 1024) return Std.int(size) + ' B';
    if (size < 1024 * 1024) return Std.int(size / 1024) + ' KB';
    if (size < 1024 * 1024 * 1024) return Std.int(size / (1024 * 1024)) + ' MB';
    return Std.int(size / (1024 * 1024 * 1024)) + ' GB';
}

function pickBestDownload(files:Array<Dynamic>):Dynamic
{
    var best:Dynamic = null;
    var bestScore:Float = -1;

    for (file in files)
    {
        var name:String = Std.string(file._sFile).toLowerCase();
        if (!name.endsWith('.zip'))
            continue;

        var score:Float = 0;

        var av:String = Std.string(file._sAvResult).toLowerCase();
        if (av == 'clean')
            score += 50;

        if (file._nDownloadCount != null)
            score += Std.parseFloat(Std.string(file._nDownloadCount));

        if (file._nFilesize != null)
        {
            var size:Int = Std.int(file._nFilesize);
            if (size > 0 && size < 1024 * 1024 * 1024)
                score += 10;
        }

        if (score > bestScore)
        {
            bestScore = score;
            best = file;
        }
    }

    return best;
}

function isLikelyAleFromRawList(raw:String):Bool
{
    if (raw == null || raw.length == 0)
        return true;

    var lower:String = raw.toLowerCase();
    var markerCount:Int = 0;

    for (marker in MOD_MARKERS)
    {
        if (lower.contains('\n' + marker + '/') || lower.startsWith(marker + '/') || lower.contains('/' + marker + '/'))
            markerCount++;
    }

    var hasPack:Bool = lower.contains('pack.json');
    var hasCore:Bool = lower.contains('data/') || lower.contains('images/') || lower.contains('songs/') || lower.contains('scripts/');
    var hasAleSpecific:Bool = false;
    var markerIndex:Int = 0;
    while (markerIndex < ALE_STRICT_MARKERS.length)
    {
        if (lower.contains(ALE_STRICT_MARKERS[markerIndex]))
        {
            hasAleSpecific = true;
            break;
        }
        markerIndex++;
    }

    var hasLegacy:Bool = false;
    for (legacy in LEGACY_PSYCH_MARKERS)
    {
        if (lower.contains('\n' + legacy + '/') || lower.contains('/' + legacy + '/'))
        {
            hasLegacy = true;
            break;
        }
    }

    if (config.strictAleDetection && !config.allowLegacyPsychMods && hasLegacy)
        return false;

    if (config.strictAleDetection)
    {
        var hasDataJson:Bool = lower.contains('data/data.json');
        var hasScriptStates:Bool = lower.contains('scripts/states/') || lower.contains('scripts/substates/') || lower.contains('scripts/states/menus/');
        return hasDataJson && hasScriptStates && hasAleSpecific && ((hasPack && markerCount >= 1) || (hasCore && markerCount >= 2));
    }

    return (hasPack && markerCount >= 1) || (hasCore && markerCount >= 2);
}

function installArchiveFromFile(zipPath:String, displayName:String, sourceUrl:String, remoteName:String):Dynamic
{
    var tmpRoot:String = getDownloaderTmpRoot();
    var stageDir:String = joinPath([tmpRoot, 'stage_' + Date.now().getTime()]);
    ensureDir(stageDir);

    if (!unzipTo(zipPath, stageDir))
        return {success: false, message: 'Failed to extract ZIP archive.'};

    extractNestedZips(stageDir, 2);

    var bestRoot:String = findBestModRoot(stageDir);
    if (bestRoot == null)
        return {success: false, message: 'Archive not recognized as ALE Psych mod.'};

    if (!isAlePsychRoot(bestRoot))
        return {success: false, message: 'Detected content is not ALE Psych format.'};

    var safeName:String = sanitizeName(displayName);
    if (safeName.length == 0)
        safeName = sanitizeName(remoteName);
    if (safeName.length == 0)
        safeName = 'mod_' + Date.now().getTime();

    var outputDir:String = joinPath([Paths.mods, safeName]);

    try
    {
        if (FileSystem.exists(outputDir))
            deleteDirectoryRecursive(outputDir);
        ensureDir(outputDir);
    }
    catch (e:Dynamic)
    {
        return {success: false, message: 'Failed preparing destination directory.'};
    }

    var copied:Int = copyDirectoryContents(bestRoot, outputDir);
    if (copied <= 0)
        return {success: false, message: 'No files copied to destination.'};

    ensurePackJson(outputDir, displayName, sourceUrl);
    File.saveContent(joinPath([outputDir, 'mod_url.txt']), sourceUrl);

    return {success: true, message: 'Installed "' + safeName + '" with ' + copied + ' files.'};
}

function findBestModRoot(stageDir:String):String
{
    var dirs:Array<String> = [];
    collectDirectories(stageDir, dirs);

    var best:String = null;
    var bestScore:Int = -1;

    for (dir in dirs)
    {
        var score:Int = scoreDirectory(dir);
        if (score > bestScore)
        {
            bestScore = score;
            best = dir;
        }
    }

    if (bestScore <= 0)
        return null;

    return best;
}

function scoreDirectory(dir:String):Int
{
    if (!FileSystem.exists(dir) || !FileSystem.isDirectory(dir))
        return -1;

    var score:Int = 0;
    var markerCount:Int = 0;
    var hasPack:Bool = false;
    var hasCore:Bool = false;
    var legacyHits:Int = 0;

    for (item in FileSystem.readDirectory(dir))
    {
        var low:String = item.toLowerCase();
        if (MOD_MARKERS.contains(low))
        {
            markerCount++;
            score += 2;
        }

        if (low == 'pack.json')
        {
            hasPack = true;
            score += 4;
        }

        if (low == 'data' || low == 'images' || low == 'songs' || low == 'scripts')
            hasCore = true;

        if (LEGACY_PSYCH_MARKERS.contains(low))
            legacyHits++;
    }

    if (hasPack)
        score += 4;
    if (hasCore)
        score += 3;
    if (markerCount >= 3)
        score += 4;

    if (hasObviousNonModPayload(dir))
        score -= 8;

    if (config.strictAleDetection && !config.allowLegacyPsychMods && legacyHits > 0)
        score -= 20;

    return score;
}

function isAlePsychRoot(dir:String):Bool
{
    if (!FileSystem.exists(dir) || !FileSystem.isDirectory(dir))
        return false;

    var markerCount:Int = 0;
    var hasPack:Bool = false;
    var hasCore:Bool = false;
    var legacyHits:Int = 0;
    var hasAleSpecific:Bool = false;

    for (item in FileSystem.readDirectory(dir))
    {
        var low:String = item.toLowerCase();
        if (MOD_MARKERS.contains(low))
            markerCount++;
        if (low == 'pack.json')
            hasPack = true;
        if (low == 'data' || low == 'images' || low == 'songs' || low == 'scripts')
            hasCore = true;

        if (LEGACY_PSYCH_MARKERS.contains(low))
            legacyHits++;

        if (low == 'scripts')
        {
            var s1:String = joinPath([dir, 'scripts', 'states']);
            var s2:String = joinPath([dir, 'scripts', 'substates']);
            var s3:String = joinPath([dir, 'scripts', 'states', 'menus']);
            if (FileSystem.exists(s1) || FileSystem.exists(s2) || FileSystem.exists(s3))
                hasAleSpecific = true;
        }

        if (low == 'data')
        {
            var d1:String = joinPath([dir, 'data', 'data.json']);
            if (FileSystem.exists(d1))
                hasAleSpecific = true;
        }
    }

    if (hasObviousNonModPayload(dir) && markerCount < 2)
        return false;

    if (config.strictAleDetection && !config.allowLegacyPsychMods && legacyHits > 0)
        return false;

    if (config.strictAleDetection)
    {
        if (!hasAleSpecific)
            return false;

        var strictData:String = joinPath([dir, 'data', 'data.json']);
        var strictScripts:String = joinPath([dir, 'scripts', 'states']);
        var strictSubstates:String = joinPath([dir, 'scripts', 'substates']);
        var strictMenus:String = joinPath([dir, 'scripts', 'states', 'menus']);

        if (!FileSystem.exists(strictData))
            return false;

        if (!(FileSystem.exists(strictScripts) || FileSystem.exists(strictSubstates) || FileSystem.exists(strictMenus)))
            return false;
    }

    return (hasPack && markerCount >= 1) || (hasCore && markerCount >= 2);
}

function hasObviousNonModPayload(dir:String):Bool
{
    var badHits:Int = 0;
    for (item in FileSystem.readDirectory(dir))
    {
        var low:String = item.toLowerCase();
        if (low.endsWith('.exe') || low.endsWith('.apk') || low.endsWith('.app') || low.endsWith('.dll') || low == 'engine' || low == 'project.godot')
            badHits++;
    }
    return badHits > 0;
}

function collectDirectories(path:String, out:Array<String>)
{
    if (!FileSystem.exists(path) || !FileSystem.isDirectory(path))
        return;

    out.push(path);

    for (item in FileSystem.readDirectory(path))
    {
        var cur:String = joinPath([path, item]);
        if (FileSystem.isDirectory(cur))
            collectDirectories(cur, out);
    }
}

function copyDirectoryContents(fromDir:String, toDir:String):Int
{
    ensureDir(toDir);

    var copied:Int = 0;
    for (item in FileSystem.readDirectory(fromDir))
        copied += copyPath(joinPath([fromDir, item]), joinPath([toDir, item]));
    return copied;
}

function copyPath(fromPath:String, toPath:String):Int
{
    if (FileSystem.isDirectory(fromPath))
    {
        ensureDir(toPath);
        var count:Int = 0;
        for (item in FileSystem.readDirectory(fromPath))
            count += copyPath(joinPath([fromPath, item]), joinPath([toPath, item]));
        return count;
    }

    var parent:String = directoryOf(toPath);
    if (parent.length > 0)
        ensureDir(parent);

    var bytes = File.getBytes(fromPath);
    File.saveBytes(toPath, bytes);
    return 1;
}

function networkGetText(url:String):String
{
    lastNetworkError = '';

    var res:Dynamic = httpGetTextRequest(url, 30, 'ALEPsychModDownloader/1.1', null);
    if (res.ok)
        return Std.string(res.data);

    lastNetworkError = trimError(Std.string(res.err));
    return '';
}

function networkDownloadFile(url:String, outPath:String):Bool
{
    lastNetworkError = '';

    var res:Dynamic = httpDownloadToFileRequest(url, outPath, 180, 'ALEPsychModDownloader/1.1', 'https://gamebanana.com/');
    if (res.ok)
        return true;

    lastNetworkError = trimError(Std.string(res.err));
    return false;
}

function httpGetTextRequest(url:String, timeoutSeconds:Int, userAgent:String, referer:String):Dynamic
{
    var data:String = '';
    var err:String = '';
    var req:Http = null;

    try
    {
        req = new Http(url);
        req.cnxTimeout = timeoutSeconds;
        req.setHeader('User-Agent', userAgent);
        req.setHeader('Accept', '*/*');
        if (referer != null && referer.length > 0)
            req.setHeader('Referer', referer);

        req.onData = function(text:String)
        {
            data = text;
        };

        req.onError = function(message:String)
        {
            err = message;
        };

        req.request(false);
    }
    catch (e:Dynamic)
    {
        err = Std.string(e);
    }

    if (err.length == 0 && data != null && data.length > 0)
    {
        return {
            ok: true,
            data: data,
            err: ''
        };
    }

    var fallback:String = err;
    if (fallback == null || fallback.length == 0)
        fallback = 'Empty response';

    return {
        ok: false,
        data: '',
        err: fallback
    };
}

function httpDownloadToFileRequest(url:String, outPath:String, timeoutSeconds:Int, userAgent:String, referer:String):Dynamic
{
    var bytes:Bytes = null;
    var err:String = '';
    var req:Http = null;

    try
    {
        req = new Http(url);
        req.cnxTimeout = timeoutSeconds;
        req.setHeader('User-Agent', userAgent);
        req.setHeader('Accept', '*/*');
        if (referer != null && referer.length > 0)
            req.setHeader('Referer', referer);

        req.onBytes = function(value:Bytes)
        {
            bytes = value;
        };

        req.onData = function(text:String)
        {
            bytes = Bytes.ofString(text);
        };

        req.onError = function(message:String)
        {
            err = message;
        };

        req.request(false);
    }
    catch (e:Dynamic)
    {
        err = Std.string(e);
    }

    if (err.length == 0 && bytes != null && bytes.length > 0)
    {
        try
        {
            var parent:String = directoryOf(outPath);
            if (parent.length > 0)
                ensureDir(parent);

            File.saveBytes(outPath, bytes);
            return {
                ok: true,
                err: ''
            };
        }
        catch (e:Dynamic)
        {
            err = Std.string(e);
        }
    }

    if (err == null || err.length == 0)
        err = 'Empty response';

    return {
        ok: false,
        err: err
    };
}

function execProcess(cmd:String, args:Array<String>):Dynamic
{
    var proc:Process = null;
    try
    {
        proc = new Process(cmd, args);
        var out:String = proc.stdout.readAll().toString();
        var err:String = proc.stderr.readAll().toString();
        var code:Int = proc.exitCode();
        proc.close();

        return {
            ok: code == 0,
            code: code,
            out: out,
            err: err
        };
    }
    catch (e:Dynamic)
    {
        if (proc != null)
            proc.close();

        return {
            ok: false,
            code: -1,
            out: '',
            err: Std.string(e)
        };
    }
}

function unzipTo(zipPath:String, outDir:String):Bool
{
    if (unzipToPureHaxe(zipPath, outDir))
        return true;

    var res:Dynamic = execProcess('unzip', ['-qq', '-o', zipPath, '-d', outDir]);
    return res.ok;
}

function unzipToPureHaxe(zipPath:String, outDir:String):Bool
{
    var input:sys.io.FileInput = null;
    try
    {
        ensureDir(outDir);

        input = File.read(zipPath, true);
        var entries = Reader.readZip(input);
        input.close();
        input = null;

        for (entry in entries)
        {
            var relativePath:String = sanitizeZipEntryPath(entry.fileName);
            if (relativePath.length == 0)
                continue;

            var outputPath:String = joinPath([outDir, relativePath]);
            var entryName:String = normalizePath(entry.fileName);
            var isDirectory:Bool = entryName.endsWith('/');
            if (isDirectory)
            {
                ensureDir(outputPath);
                continue;
            }

            var parent:String = directoryOf(outputPath);
            if (parent.length > 0)
                ensureDir(parent);

            if (entry.compressed)
                Reader.unzip(entry);

            File.saveBytes(outputPath, entry.data);
        }

        return true;
    }
    catch (e:Dynamic)
    {
        if (input != null)
        {
            try
            {
                input.close();
            }
            catch (ignored:Dynamic) {}
        }
        return false;
    }
}

function sanitizeZipEntryPath(path:String):String
{
    if (path == null || path.length == 0)
        return '';

    var p:String = normalizePath(path).trim();
    while (p.startsWith('/'))
        p = p.substring(1);
    while (p.startsWith('./'))
        p = p.substring(2);

    if (p.length == 0)
        return '';
    if (p.contains('../') || p.startsWith('..'))
        return '';
    if (p.length >= 2 && p.charAt(1) == ':')
        return '';

    return p;
}

function moveFile(fromPath:String, toPath:String):Bool
{
    try
    {
        if (FileSystem.exists(toPath))
            FileSystem.deleteFile(toPath);

        FileSystem.rename(fromPath, toPath);
        return true;
    }
    catch (e:Dynamic)
    {
        try
        {
            var bytes = File.getBytes(fromPath);
            File.saveBytes(toPath, bytes);
            FileSystem.deleteFile(fromPath);
            return true;
        }
        catch (copyErr:Dynamic)
        {
            return false;
        }
    }
}

function extractNestedZips(root:String, depth:Int)
{
    if (depth <= 0)
        return;

    var zips:Array<String> = [];
    collectZipFiles(root, zips);

    for (zip in zips)
    {
        var outDir:String = zip + '__unzipped';
        ensureDir(outDir);
        unzipTo(zip, outDir);
    }

    if (zips.length > 0)
        extractNestedZips(root, depth - 1);
}

function collectZipFiles(path:String, out:Array<String>)
{
    if (!FileSystem.exists(path))
        return;

    if (FileSystem.isDirectory(path))
    {
        for (item in FileSystem.readDirectory(path))
            collectZipFiles(joinPath([path, item]), out);
        return;
    }

    if (path.toLowerCase().endsWith('.zip'))
        out.push(path);
}

function ensurePackJson(modPath:String, name:String, sourceUrl:String)
{
    var filePath:String = joinPath([modPath, 'pack.json']);
    if (FileSystem.exists(filePath))
        return;

    var finalName:String = name == null || name.trim().length == 0 ? 'Downloaded Mod' : name.trim();
    var description:String = sourceUrl == null ? '' : sourceUrl;

    File.saveContent(filePath, Json.stringify({
        name: finalName,
        description: description,
        runsGlobally: false
    }, '  '));
}

function getDownloaderRoot():String
{
    return joinPath([Paths.mods, 'moddownloader']);
}

function getDownloaderTmpRoot():String
{
    return joinPath([getDownloaderRoot(), TMP_DIR_NAME]);
}

function getDownloaderCacheRoot():String
{
    return joinPath([getDownloaderRoot(), '_moddownloader_cache']);
}

function cleanupTemp()
{
    var tmpRoot:String = getDownloaderTmpRoot();
    if (FileSystem.exists(tmpRoot))
        deleteDirectoryRecursive(tmpRoot);
}

function cleanupCache()
{
    var cacheRoot:String = getDownloaderCacheRoot();
    if (FileSystem.exists(cacheRoot))
        deleteDirectoryRecursive(cacheRoot);

    thumbAttempted = new StringMap<Bool>();
}

function sanitizeName(name:String):String
{
    if (name == null)
        return '';

    var n:String = name.toLowerCase();
    var out:String = '';

    var i:Int = 0;
    while (i < n.length)
    {
        var c:String = n.charAt(i);
        var ok:Bool = (c >= 'a' && c <= 'z') || (c >= '0' && c <= '9') || c == '-' || c == '_';
        if (ok)
            out += c;
        else if (c == ' ')
            out += '-';

        i++;
    }

    while (out.contains('--'))
        out = out.replace('--', '-');

    return out.trim();
}

function ensureDir(path:String)
{
    if (path == null || path.length == 0)
        return;
    if (FileSystem.exists(path))
        return;

    var parent:String = directoryOf(path);
    if (parent.length > 0 && !FileSystem.exists(parent))
        ensureDir(parent);

    if (!FileSystem.exists(path))
        FileSystem.createDirectory(path);
}

function directoryOf(path:String):String
{
    var p:String = normalizePath(path);
    var idx:Int = p.lastIndexOf('/');
    return idx <= 0 ? '' : p.substring(0, idx);
}

function joinPath(parts:Array<String>):String
{
    var out:String = '';
    for (part in parts)
    {
        if (part == null || part.length == 0)
            continue;

        var p:String = normalizePath(part);
        if (out.length == 0)
            out = p;
        else
        {
            if (!out.endsWith('/'))
                out += '/';
            if (p.startsWith('/'))
                p = p.substring(1);
            out += p;
        }
    }
    return out;
}

function normalizePath(path:String):String
{
    if (path == null)
        return '';

    var p:String = path.replace('\\', '/');
    while (p.contains('//'))
        p = p.replace('//', '/');
    return p;
}

function trimText(text:String, maxLen:Int):String
{
    if (text == null)
        return '';
    if (text.length <= maxLen)
        return text;
    return text.substring(0, maxLen - 3) + '...';
}

function trimError(text:String):String
{
    if (text == null)
        return '';

    var t:String = text.replace('\n', ' ').replace('\r', ' ').trim();
    while (t.contains('  '))
        t = t.replace('  ', ' ');
    if (t.length > 150)
        t = t.substring(0, 150) + '...';
    return t;
}

function isUsableImage(path:String):Bool
{
    if (path == null || path.length == 0)
        return false;
    if (!FileSystem.exists(path))
        return false;

    try
    {
        var stat = FileSystem.stat(path);
        return stat.size > 24;
    }
    catch (e:Dynamic)
    {
        return false;
    }
}

function absolutePath(path:String):String
{
    if (path == null || path.length == 0)
        return '';
    if (path.startsWith('/'))
        return path;
    return normalizePath(Sys.getCwd() + '/' + path);
}

function applySpriteImage(sprite:FlxSprite, path:String, width:Int, height:Int):Bool
{
    if (sprite == null || path == null || path.length == 0)
        return false;

    var full:String = absolutePath(path);
    if (!FileSystem.exists(full))
        return false;

    try
    {
        var bitmap:openfl.display.BitmapData = openfl.display.BitmapData.fromFile(full);
        if (bitmap == null)
            return false;

        sprite.loadGraphic(bitmap);
        sprite.setGraphicSize(width, height);
        sprite.updateHitbox();
        return true;
    }
    catch (e:Dynamic)
    {
        return false;
    }
}

function shellQuote(value:String):String
{
    if (value == null)
        return "''";

    var v:String = value;
    if (v.contains("'"))
        v = v.replace("'", "'\"'\"'");
    return "'" + v + "'";
}

function deleteDirectoryRecursive(path:String)
{
    if (!FileSystem.exists(path))
        return;

    if (!FileSystem.isDirectory(path))
    {
        FileSystem.deleteFile(path);
        return;
    }

    for (item in FileSystem.readDirectory(path))
    {
        var current:String = joinPath([path, item]);
        if (FileSystem.isDirectory(current))
            deleteDirectoryRecursive(current);
        else
            FileSystem.deleteFile(current);
    }

    FileSystem.deleteDirectory(path);
}

function pushTypedChar(char:String)
{
    if (char == null || char.length == 0)
        return;

    query += char;
    refreshHeader();
}

function captureTypingFallback()
{
    var upper:Bool = FlxG.keys.pressed.SHIFT;

    if (FlxG.keys.justPressed.SPACE) pushTypedChar(' ');
    if (FlxG.keys.justPressed.MINUS) pushTypedChar(upper ? '_' : '-');

    if (FlxG.keys.justPressed.ZERO) pushTypedChar('0');
    if (FlxG.keys.justPressed.ONE) pushTypedChar('1');
    if (FlxG.keys.justPressed.TWO) pushTypedChar('2');
    if (FlxG.keys.justPressed.THREE) pushTypedChar('3');
    if (FlxG.keys.justPressed.FOUR) pushTypedChar('4');
    if (FlxG.keys.justPressed.FIVE) pushTypedChar('5');
    if (FlxG.keys.justPressed.SIX) pushTypedChar('6');
    if (FlxG.keys.justPressed.SEVEN) pushTypedChar('7');
    if (FlxG.keys.justPressed.EIGHT) pushTypedChar('8');
    if (FlxG.keys.justPressed.NINE) pushTypedChar('9');

    if (FlxG.keys.justPressed.A) pushTypedChar(upper ? 'A' : 'a');
    if (FlxG.keys.justPressed.B) pushTypedChar(upper ? 'B' : 'b');
    if (FlxG.keys.justPressed.C) pushTypedChar(upper ? 'C' : 'c');
    if (FlxG.keys.justPressed.D) pushTypedChar(upper ? 'D' : 'd');
    if (FlxG.keys.justPressed.E) pushTypedChar(upper ? 'E' : 'e');
    if (FlxG.keys.justPressed.F) pushTypedChar(upper ? 'F' : 'f');
    if (FlxG.keys.justPressed.G) pushTypedChar(upper ? 'G' : 'g');
    if (FlxG.keys.justPressed.H) pushTypedChar(upper ? 'H' : 'h');
    if (FlxG.keys.justPressed.I) pushTypedChar(upper ? 'I' : 'i');
    if (FlxG.keys.justPressed.J) pushTypedChar(upper ? 'J' : 'j');
    if (FlxG.keys.justPressed.K) pushTypedChar(upper ? 'K' : 'k');
    if (FlxG.keys.justPressed.L) pushTypedChar(upper ? 'L' : 'l');
    if (FlxG.keys.justPressed.M) pushTypedChar(upper ? 'M' : 'm');
    if (FlxG.keys.justPressed.N) pushTypedChar(upper ? 'N' : 'n');
    if (FlxG.keys.justPressed.O) pushTypedChar(upper ? 'O' : 'o');
    if (FlxG.keys.justPressed.P) pushTypedChar(upper ? 'P' : 'p');
    if (FlxG.keys.justPressed.Q) pushTypedChar(upper ? 'Q' : 'q');
    if (FlxG.keys.justPressed.R) pushTypedChar(upper ? 'R' : 'r');
    if (FlxG.keys.justPressed.S) pushTypedChar(upper ? 'S' : 's');
    if (FlxG.keys.justPressed.T) pushTypedChar(upper ? 'T' : 't');
    if (FlxG.keys.justPressed.U) pushTypedChar(upper ? 'U' : 'u');
    if (FlxG.keys.justPressed.V) pushTypedChar(upper ? 'V' : 'v');
    if (FlxG.keys.justPressed.W) pushTypedChar(upper ? 'W' : 'w');
    if (FlxG.keys.justPressed.X) pushTypedChar(upper ? 'X' : 'x');
    if (FlxG.keys.justPressed.Y) pushTypedChar(upper ? 'Y' : 'y');
    if (FlxG.keys.justPressed.Z) pushTypedChar(upper ? 'Z' : 'z');
}
