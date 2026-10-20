Sub Main
    Dim ws As Object
    Dim lastRow As Long
    Dim i As Long
    Dim govCol As Long
    Dim yearCol As Long
    Dim govName As String
    Dim harvestYear As Variant


    ws = ThisComponent.Sheets.getByName("model_table")


    govCol = 0
    yearCol = 1


    lastRow = 335


    ThisComponent.lockControllers()


    For i = lastRow To 1 Step -1

        govName = LCase(Trim(ws.getCellByPosition(govCol, i).String))
        harvestYear = ws.getCellByPosition(yearCol, i).Value


        If IsNumeric(harvestYear) And harvestYear <> 0 Then
            If harvestYear < 2000 Then
                ws.Rows.removeByIndex(i, 1)
                GoTo NextIteration
            End If
        End If


        Select Case govName
            Case "tatouine", "tataouine", "ben arous", _
                 "ariana", "kébili", "kébili", "kebili", _
                 "tozeur"

                ws.Rows.removeByIndex(i, 1)
        End Select

NextIteration:
    Next i


    ThisComponent.unlockControllers()

   

End Sub

