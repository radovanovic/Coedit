unit ce_libman;

{$I ce_defines.inc}

interface

uses
  Classes, SysUtils, FileUtil, ce_common, ce_writableComponent, ce_dcd;

type

  (**
   * Represents a D static library. In a project libAlias allows to
   * resolve automatically the dependencies of a project.
   *)
  TLibraryItem = class(TCollectionItem)
  private
    fAlias: string;
    fSourcePath: string;
    fLibFile: string;
  published
    property libAlias: string read fAlias write fAlias;
    property libSourcePath: string read fSourcePath write fSourcePath;
    property libFile: string read fLibFile write fLibFile;
  end;

  (**
   * Represents all the D libraries present on this system.
   *)
  TLibraryManager = class(TWritableLfmTextComponent)
  private
    fCol: TCollection;
    procedure setCol(const aValue: TCollection);
  protected
    procedure afterLoad; override;
  published
    property libraries: TCollection read fCol write setCol;
  public
    constructor create(aOwner: TComponent); override;
    destructor destroy; override;
    //
    procedure getLibFiles(someAliases, aList: TStrings);
    procedure getLibSources(someAliases, aList: TStrings);
    //
    procedure updateDCD;
  end;

const
  libFname = 'libraryManager.txt';

var
  LibMan: TLibraryManager;

implementation

constructor TLibraryManager.create(aOwner: TComponent);
var
  fName: string;
begin
  inherited;
  fCol := TCollection.Create(TLibraryItem);
  fname := getCoeditDocPath + libFname;
  if fileExists(fname) then loadFromFile(fname);
end;

destructor TLibraryManager.destroy;
begin
  forceDirectory(getCoeditDocPath);
  LibMan.saveToFile(getCoeditDocPath + libFname);
  fCol.Free;
  inherited;
end;

procedure TLibraryManager.setCol(const aValue: TCollection);
begin
  fCol.assign(aValue);
end;

procedure TLibraryManager.updateDCD;
var
  itm: TLibraryItem;
  i: Integer;
begin
  if not DcdWrapper.available then exit;
  // note: new items are directly handled but removed ones still in cache until server restarts.
  for i := 0 to fCol.Count-1 do
  begin
    itm := TLibraryItem(fCol.Items[i]);
    DcdWrapper.addImportFolder(itm.libSourcePath);
  end;
end;

(**
 * the caller gets all the *.lib/*.a files in aList if someAliases is nil
 * otherwise the static libs selected by the aliases in someAliases.
 *)
procedure TLibraryManager.getLibFiles(someAliases, aList: TStrings);
var
  itm: TLibraryItem;
  lst: TStringList;
  i,j: Integer;
  dir: string;
begin
  for i := 0 to fCol.Count-1 do
  begin
    itm := TLibraryItem(fCol.Items[i]);
    if someAliases <> nil then
      if someAliases.IndexOf(itm.libAlias) = -1 then
        continue;
    // single lib files
    if fileExists(itm.libFile) then
    begin
      if aList.IndexOf(itm.libFile) <> -1 then
        continue;
      aList.Add(itm.libFile);
    end
    // folder of lib file
    else if directoryExists(itm.libFile) then
    begin
      lst := TStringList.Create;
      try
        dir := itm.libFile;
        if itm.libFile[length(dir)] = DirectorySeparator then
          dir := dir[1..length(dir)-1];
        listFiles(lst, dir);
        for j:= 0 to lst.Count-1 do
        begin
          if extractFileExt(lst.Strings[j]) = libExt then
            if aList.IndexOf(lst.Strings[j]) = -1 then
              aList.Add(lst.Strings[j]);
        end;
      finally
        lst.Free;
      end;
    end;
  end;
end;

(**
 * the caller gets all the paths were are located the lib sources in aList if someAliases is nil
 * otherwise the paths where are located the lib sources selected by the aliases in someAliases.
 *)
procedure TLibraryManager.getLibSources(someAliases, aList: TStrings);
var
  itm: TLibraryItem;
  i: Integer;
begin
  for i := 0 to fCol.Count-1 do
  begin
    itm := TLibraryItem(fCol.Items[i]);
    if someAliases <> nil then
      if someAliases.IndexOf(itm.libAlias) = -1 then
        continue;
    //
    if aList.IndexOf(itm.libSourcePath) <> -1 then
      continue;
    if not directoryExists(itm.libSourcePath) then
      continue;
    aList.Add('-I' + itm.libSourcePath);
  end;
end;

procedure TLibraryManager.afterLoad;
begin
  updateDCD;
end;

initialization
  registerClasses([TLibraryManager, TLibraryItem]);
  LibMan := TLibraryManager.create(nil);
finalization
  LibMan.Free;
end.
