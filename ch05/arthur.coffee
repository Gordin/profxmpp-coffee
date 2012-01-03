Arthur =
    connection: null

    handle_message: (message) ->
        if $(message).attr('from').match(/^update@identi.ca/)
            delayed = $(message).find('delay').length > 0
            body = $(message).find('html > body').contents()

            div = $("<div></div>")

            div.addClass('delayed') if delayed

            body.each ->
                if document.importNode
                    $(document.importNode(this, true)).appendTo div
                else
                    # IE workaround
                    div.append this.xml

            div.prependTo '#stream'

        true

jQuery ->
    $('#login_dialog').dialog(
        autoOpen: true
        draggable: false
        modal: true
        title: 'Connect to XMPP'
        buttons:
            "Connect": ->
                $(document).trigger(
                    'connect'
                    jid: $('#jid').val().toLowerCase()
                    password: $('#password').val()
                )

                $('#password').val ''
                $(this).dialog 'close'
    )

    $('#input').keyup( ->
        left = 140 - $(this).val().length
        $('#counter .count').text('' + left)
    )

    $('#input').keypress (ev) ->
        if ev.which is 13
            ev.preventDefault()

            text = $(this).val()
            $(this).val ''

            msg = $msg(
                to: 'update@identi.ca'
                type: 'chat')
                .c('body')
                .t(text)
            Arthur.connection.send msg

    $(document).bind(
        'connect'
        (ev, data) ->
            conn = new Strophe.Connection "http://bosh.metajack.im:5280/xmpp-httpbind"

            conn.connect(
                data.jid
                data.password
                (status) ->
                    if status is Strophe.Status.CONNECTED
                        $(document).trigger 'connected'
                    else if status is Strophe.Status.DISCONNECTED
                        $(document).trigger 'disconnected'
            )
            Arthur.connection = conn
    )

    $(document).bind(
        'connected'
        ->
            Arthur.connection.addHandler(
                Arthur.handle_message
                null
                "message"
                "chat"
            )
            Arthur.connection.send $pres()
    )

    $(document).bind(
        'disconnected'
        -> # nothing here yet
    )

