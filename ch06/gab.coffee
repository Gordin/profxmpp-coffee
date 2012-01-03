Gab =
    connection: null

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
                    jid: $('#jid').val()
                    password: $('#password').val()
                )

                $('#password').val ''
                $(this).dialog 'close'
    )

    $(document).bind(
        'connect'
        (ev, data) ->
            conn = new Strophe.Connection 'http://bosh.metajack.im:5280/xmpp-httpbind'
            conn.connect(
                data.jid
                data.password
                (status) ->
                    if status is Strophe.Status.CONNECTED
                        $(document).trigger 'connected'
                    else if status is Strophe.Status.DISCONNECTED
                        $(document).trigger 'disconnected'
            )
            Gab.connection = conn
    )

    $(document).bind(
        'connected'
        -> # nothing here yet
    )

    $(document).bind(
        'disconnected'
         -> # nothing here yet
    )
