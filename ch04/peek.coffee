class History
    constructor: ->
        @commands = []
        @cur = -1
    add: (command) ->
        if command isnt ""
            @commands.push(command)
            @cur = @commands.length
    get: (keyup) ->
        if @commands.length is 0
            return ""
        switch (keyup.which)
            when 38
                @cur = 0 if --@cur <= 0
                return @commands[@cur]
            when 40
                @cur = @commands.length - 1 if ++@cur >= @commands.length
                return @commands[@cur]
            else
                return ""

Peek =
    connection : null

    show_traffic: (body, type) ->
        if body.childNodes.length > 0
            console = $('#console').get(0)
            at_bottom =
                console.scrollTop >= console.scrollHeight - console.clientHeight

            $.each body.childNodes, ->
                $('#console').append(
                    "<div class='foldable #{type}'>#{Peek.pretty_xml(this)}</div>"
                )

            if at_bottom
                console.scrollTop = console.scrollHeight

    pretty_xml: (xml, level = 0) ->
        result = [
            "<div class='xml_level#{level}'>"
            "<span class='xml_punc'>&lt;</span>"
            "<span class='xml_tag'>", xml.tagName, "</span>"]

        # attributes
        attrs = xml.attributes
        attr_lead = ("&nbsp;" for _ in [1..xml.tagName.length]).join ""

        for attr, i in attrs
            result.push(str) for str in [
                " <span class='xml_aname'>", attr.nodeName
                "</span><span class='xml_punc'>='</span>"
                "<span class='xml_avalue'>", attr.nodeValue
                "</span><span class='xml_punc'>'</span>"]
            if i < attrs.length - 1
                result.push "</div><div class='xml_level#{level}'>"
                result.push attr_lead


        if xml.childNodes.length is 0
            result.push "<span class='xml_punc'>/&gt;</span></div>"
        else
            result.push "<span class='xml_punc'>&gt;</span></div>"

            # children
            $.each(xml.childNodes, ->
                if this.nodeType is 1
                    result.push(Peek.pretty_xml(this, level + 1))
                else if this.nodeType is 3
                    result.push(str) for str in [
                        "<div class='xml_text xml_level#{level+1}'>"
                        this.nodeValue, "</div>"]
            )

            result.push(str) for str in [
                "<div class='xml xml_level#{level}'>"
                "<span class='xml_punc'>&lt;/</span>"
                "<span class='xml_tag'>", xml.tagName, "</span>"
                "<span class='xml_punc'>&gt;</span></div>"]

        result.join ""

    text_to_xml: (text) ->
        if window['DOMParser']
            parser = new DOMParser()
            doc = parser.parseFromString(text, 'text/xml')
        else if  window['ActiveXObject']
            doc = new ActiveXObject "MSXML2.DOMDocument"
            doc.async = false
            doc.loadXML text
        else
            throw
                type: 'PeekError',
                message: 'No DOMParser object found.'

        elem = doc.documentElement
        if $(elem).filter('parsererror').length > 0
            return null
        elem


jQuery ->
    hist = new History()

    $('#login_dialog').dialog(
        autoOpen  : yes
        draggable : no
        modal     : yes
        title     : 'Connect to XMPP'
        buttons:
            "Connect": ->
                $(document).trigger(
                    'connect'
                    jid      : $('#jid').val()
                    password : $('#password').val() )
                $('#password').val ''
                $(this).dialog 'close'
    )

    $('#disconnect_button').click -> Peek.connection.disconnect()

    $('#send_button').click ->
        input = $('#input').val()
        hist.add(input)
        error = false
        if input.length > 0
            if input[0] is '<'
                xml = Peek.text_to_xml input
                if xml
                    Peek.connection.send xml
                    $('#input').val ''
                else
                    error = true
            else if input[0] is '$'
                try
                    builder = eval input
                    Peek.connection.send builder
                    $('#input').val ''
                catch e
                    error = true
            else
                error = true
        if error
            $('#input').animate backgroundColor : "#faa"

    $('#input').keypress ->
        $(this).css backgroundColor : '#fff'

    $('#input').keyup (keycode) ->
        command = hist.get keycode
        if command isnt ""
            $('#input').val command

    $(document).bind(
        'connect'
        (ev, data) ->
            conn = new Strophe.Connection(
                "http://bosh.metajack.im:5280/xmpp-httpbind")

            conn.xmlInput  = (body) -> Peek.show_traffic(body, 'incoming')
            conn.xmlOutput = (body) -> Peek.show_traffic(body, 'outgoing')

            conn.connect(
                data.jid
                data.password
                (status) ->
                    if status is Strophe.Status.CONNECTED
                        $(document).trigger 'connected'
                    else if status is Strophe.Status.DISCONNECTED
                        $(document).trigger 'disconnected'
            )
            Peek.connection = conn
    )

    $(document).bind(
        'connected'
        ->
            $('.button').removeAttr('disabled')
            $('#input').removeClass('disabled').removeAttr('disabled')

    )

    $(document).bind(
        'disconnected'
        ->
            $('.button').attr('disabled', 'disabled')
            $('#input').addClass('disabled').attr('disabled', 'disabled')
            Peek.connection = null
    )

    $('#console').on(
        "click"
        ".foldable"
        ->
            childs = $(this.children).filter((i) -> i > 0)
            if childs.length is 0
                return
            visible = $(childs[0]).filter(":visible")
            if visible.length is 0
                childs.show()
            else
                childs.hide()
    )
