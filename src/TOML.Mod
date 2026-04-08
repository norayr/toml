MODULE TOML;
IMPORT Strings;

CONST
  MaxKeyLen = 128;
  MaxValLen = 4096;
  MaxSecLen = 128;

  (* Parser states *)
  psLINE    = 0;
  psSEC     = 1;
  psKEY     = 2;
  psAFTEREQ = 3;
  psUNQ     = 4;
  psQUOT    = 5;
  psCOMMENT = 6;
  psREST    = 7;

TYPE
  Field* = POINTER TO FieldDesc;
  FieldDesc* = RECORD
    key*:   ARRAY MaxKeyLen OF CHAR;
    value*: ARRAY MaxValLen OF CHAR;
    next*:  Field
  END;

  Section* = POINTER TO SectionDesc;
  SectionDesc* = RECORD
    name*:  ARRAY MaxSecLen OF CHAR;
    first*: Field;
    next*:  Section
  END;

  Doc* = POINTER TO DocDesc;
  DocDesc* = RECORD
    first*: Section
  END;

PROCEDURE ToLower*(VAR s: ARRAY OF CHAR);
VAR i: INTEGER;
BEGIN
  i := 0;
  WHILE s[i] # 0X DO
    IF (s[i] >= "A") & (s[i] <= "Z") THEN s[i] := CHR(ORD(s[i]) + 20H) END;
    INC(i)
  END
END ToLower;

PROCEDURE TrimRight*(VAR s: ARRAY OF CHAR);
VAR i: INTEGER;
BEGIN
  i := Strings.Length(s) - 1;
  WHILE (i >= 0) & ((s[i] = " ") OR (s[i] = 09X) OR (s[i] = 0DX) OR (s[i] = 0AX)) DO
    s[i] := 0X; DEC(i)
  END
END TrimRight;

PROCEDURE TrimLeft*(VAR s: ARRAY OF CHAR);
VAR i, j, l: INTEGER;
BEGIN
  i := 0;
  WHILE (s[i] = " ") OR (s[i] = 09X) DO INC(i) END;
  IF i > 0 THEN
    l := Strings.Length(s);
    j := 0;
    WHILE i <= l DO s[j] := s[i]; INC(i); INC(j) END
  END
END TrimLeft;

PROCEDURE Trim*(VAR s: ARRAY OF CHAR);
BEGIN TrimRight(s); TrimLeft(s) END Trim;

PROCEDURE Parse*(VAR content: ARRAY OF CHAR): Doc;
VAR
  doc:     Doc;
  curSec:  Section;
  curFld:  Field;
  lastSec: Section;
  lastFld: Field;
  ch:      CHAR;
  pos:     LONGINT;
  state:   INTEGER;
  secBuf:  ARRAY MaxSecLen OF CHAR;
  keyBuf:  ARRAY MaxKeyLen OF CHAR;
  valBuf:  ARRAY MaxValLen OF CHAR;
  nPos, kPos, vPos: INTEGER;
BEGIN
  NEW(doc); doc^.first := NIL;
  curSec := NIL; lastSec := NIL; lastFld := NIL;
  state := psLINE;
  nPos := 0; kPos := 0; vPos := 0;
  secBuf[0] := 0X; keyBuf[0] := 0X; valBuf[0] := 0X;
  pos := 0;

  WHILE content[pos] # 0X DO
    ch := content[pos];

    IF state = psLINE THEN
      IF (ch = " ") OR (ch = 09X) OR (ch = 0DX) THEN
        (* skip whitespace and CR *)
      ELSIF ch = 0AX THEN
        (* blank line *)
      ELSIF ch = "#" THEN
        state := psCOMMENT
      ELSIF ch = "[" THEN
        nPos := 0; secBuf[0] := 0X;
        state := psSEC
      ELSE
        keyBuf[0] := ch; kPos := 1;
        state := psKEY
      END

    ELSIF state = psSEC THEN
      IF ch = "]" THEN
        secBuf[nPos] := 0X;
        Trim(secBuf);
        IF secBuf[0] # 0X THEN
          NEW(curSec);
          COPY(secBuf, curSec^.name);
          curSec^.first := NIL; curSec^.next := NIL;
          lastFld := NIL;
          IF doc^.first = NIL THEN doc^.first := curSec
          ELSE lastSec^.next := curSec
          END;
          lastSec := curSec
        END;
        nPos := 0; secBuf[0] := 0X;
        state := psREST
      ELSIF (ch = 0AX) OR (ch = 0DX) THEN
        nPos := 0; secBuf[0] := 0X; state := psLINE
      ELSE
        IF nPos < MaxSecLen - 1 THEN secBuf[nPos] := ch; INC(nPos) END
      END

    ELSIF state = psKEY THEN
      IF ch = "=" THEN
        keyBuf[kPos] := 0X;
        TrimRight(keyBuf);
        vPos := 0; valBuf[0] := 0X;
        state := psAFTEREQ
      ELSIF (ch = 0AX) OR (ch = 0DX) THEN
        kPos := 0; keyBuf[0] := 0X; state := psLINE
      ELSIF ch = "#" THEN
        kPos := 0; keyBuf[0] := 0X; state := psCOMMENT
      ELSE
        IF kPos < MaxKeyLen - 1 THEN keyBuf[kPos] := ch; INC(kPos) END
      END

    ELSIF state = psAFTEREQ THEN
      IF (ch = " ") OR (ch = 09X) THEN
        (* skip whitespace after = *)
      ELSIF ch = '"' THEN
        vPos := 0; valBuf[0] := 0X;
        state := psQUOT
      ELSIF (ch = 0AX) OR (ch = 0DX) THEN
        (* empty value - flush field *)
        valBuf[0] := 0X;
        IF (curSec # NIL) & (kPos > 0) THEN
          NEW(curFld);
          COPY(keyBuf, curFld^.key);
          COPY(valBuf, curFld^.value);
          curFld^.next := NIL;
          IF curSec^.first = NIL THEN curSec^.first := curFld
          ELSE lastFld^.next := curFld
          END;
          lastFld := curFld
        END;
        kPos := 0; keyBuf[0] := 0X; vPos := 0; valBuf[0] := 0X;
        state := psLINE
      ELSIF ch = "#" THEN
        valBuf[0] := 0X;
        IF (curSec # NIL) & (kPos > 0) THEN
          NEW(curFld);
          COPY(keyBuf, curFld^.key);
          COPY(valBuf, curFld^.value);
          curFld^.next := NIL;
          IF curSec^.first = NIL THEN curSec^.first := curFld
          ELSE lastFld^.next := curFld
          END;
          lastFld := curFld
        END;
        kPos := 0; keyBuf[0] := 0X; vPos := 0; valBuf[0] := 0X;
        state := psCOMMENT
      ELSE
        vPos := 0; valBuf[0] := ch; INC(vPos);
        state := psUNQ
      END

    ELSIF state = psUNQ THEN
      IF (ch = 0AX) OR (ch = 0DX) THEN
        valBuf[vPos] := 0X; TrimRight(valBuf);
        IF (curSec # NIL) & (kPos > 0) THEN
          NEW(curFld);
          COPY(keyBuf, curFld^.key);
          COPY(valBuf, curFld^.value);
          curFld^.next := NIL;
          IF curSec^.first = NIL THEN curSec^.first := curFld
          ELSE lastFld^.next := curFld
          END;
          lastFld := curFld
        END;
        kPos := 0; keyBuf[0] := 0X; vPos := 0; valBuf[0] := 0X;
        state := psLINE
      ELSIF ch = "#" THEN
        valBuf[vPos] := 0X; TrimRight(valBuf);
        IF (curSec # NIL) & (kPos > 0) THEN
          NEW(curFld);
          COPY(keyBuf, curFld^.key);
          COPY(valBuf, curFld^.value);
          curFld^.next := NIL;
          IF curSec^.first = NIL THEN curSec^.first := curFld
          ELSE lastFld^.next := curFld
          END;
          lastFld := curFld
        END;
        kPos := 0; keyBuf[0] := 0X; vPos := 0; valBuf[0] := 0X;
        state := psCOMMENT
      ELSE
        IF vPos < MaxValLen - 1 THEN valBuf[vPos] := ch; INC(vPos) END
      END

    ELSIF state = psQUOT THEN
      IF ch = '"' THEN
        valBuf[vPos] := 0X;
        IF (curSec # NIL) & (kPos > 0) THEN
          NEW(curFld);
          COPY(keyBuf, curFld^.key);
          COPY(valBuf, curFld^.value);
          curFld^.next := NIL;
          IF curSec^.first = NIL THEN curSec^.first := curFld
          ELSE lastFld^.next := curFld
          END;
          lastFld := curFld
        END;
        kPos := 0; keyBuf[0] := 0X; vPos := 0; valBuf[0] := 0X;
        state := psREST
      ELSIF ch = 0DX THEN
        (* skip CR, store LF only *)
      ELSE
        (* store everything including newlines (0AX) *)
        IF vPos < MaxValLen - 1 THEN valBuf[vPos] := ch; INC(vPos) END
      END

    ELSE (* psCOMMENT or psREST *)
      IF ch = 0AX THEN state := psLINE END
    END;

    INC(pos)
  END;

  (* flush remaining unquoted value at EOF *)
  IF (state = psUNQ) & (kPos > 0) & (curSec # NIL) THEN
    valBuf[vPos] := 0X; TrimRight(valBuf);
    NEW(curFld);
    COPY(keyBuf, curFld^.key);
    COPY(valBuf, curFld^.value);
    curFld^.next := NIL;
    IF curSec^.first = NIL THEN curSec^.first := curFld
    ELSE lastFld^.next := curFld
    END
  END;

  RETURN doc
END Parse;

PROCEDURE GetSection*(doc: Doc; VAR name: ARRAY OF CHAR): Section;
VAR
  sec: Section;
  sn, nn: ARRAY MaxSecLen OF CHAR;
BEGIN
  IF doc = NIL THEN RETURN NIL END;
  COPY(name, nn); ToLower(nn);
  sec := doc^.first;
  WHILE sec # NIL DO
    COPY(sec^.name, sn); ToLower(sn);
    IF sn = nn THEN RETURN sec END;
    sec := sec^.next
  END;
  RETURN NIL
END GetSection;

PROCEDURE GetNextSection*(prev: Section; VAR name: ARRAY OF CHAR): Section;
VAR
  sec: Section;
  sn, nn: ARRAY MaxSecLen OF CHAR;
BEGIN
  IF prev = NIL THEN RETURN NIL END;
  COPY(name, nn); ToLower(nn);
  sec := prev^.next;
  WHILE sec # NIL DO
    COPY(sec^.name, sn); ToLower(sn);
    IF sn = nn THEN RETURN sec END;
    sec := sec^.next
  END;
  RETURN NIL
END GetNextSection;

PROCEDURE GetField*(sec: Section; VAR key: ARRAY OF CHAR; VAR value: ARRAY OF CHAR): BOOLEAN;
VAR
  fld: Field;
  fk, wk: ARRAY MaxKeyLen OF CHAR;
BEGIN
  COPY("", value);
  IF sec = NIL THEN RETURN FALSE END;
  COPY(key, wk); ToLower(wk);
  fld := sec^.first;
  WHILE fld # NIL DO
    COPY(fld^.key, fk); ToLower(fk);
    IF fk = wk THEN COPY(fld^.value, value); RETURN TRUE END;
    fld := fld^.next
  END;
  RETURN FALSE
END GetField;

END TOML.
