Gab =
    connection: null

    on_roster: (iq) ->
        $(iq).find('item').each ->
            jid = $(this).attr 'jid'
            name = $(this).attr('name') || jid

            # transform jid into an id
            jid_id = Gab.jid_to_id jid

            contact = $("<li id='#{jid_id}'>" +
                "<div class='roster-contact offline'>" +
                "<div class='roster-name'>#{name}</div>" +
                "<div class='roster-jid'>#{jid}</div></div></li>")

            Gab.insert_contact contact

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
        ->
            iq = $iq(type: 'get')
                .c('query', xmlns: 'jabber:iq:roster')
            Gab.connection.sendIQ(iq, Gab.on_roster)
    )

    $(document).bind(
        'disconnected'
         -> # nothing here yet
    )
