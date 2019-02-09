"""
   Copyright (c) 2017, the University of Oregon
   All rights reserved.

   Redistribution and use in source and binary forms, with or without
   modification, are permitted provided that the following conditions are met:

   - Redistributions of source code must retain the above copyright notice,
     this list of conditions and the following disclaimer.
  
   - Redistributions in binary form must reproduce the above copyright notice,
     this list of conditions and the following disclaimer in the documentation
     and/or other materials provided with the distribution.
  
   - Neither the name of the University of Oregon nor the names of its
     contributors may be used to endorse or promote products derived from this
     software without specific prior written permission.
  
   THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
   AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
   IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
   ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE
   LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
   CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
   SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
   INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
   CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
   ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
   POSSIBILITY OF SUCH DAMAGE.
"""

class LLNode(object):
    """
    a linked list node object - we only define a constructor
    all other manipulations take place via mods to the public fields
    """

    def __init__(self, data=None):
        self.data = data
        self.nextn = None
        self.prevn = None

class LinkedList(object):
    """
    a linked list object - implemented using a doubly-linked list with sentinel
    """

    def __relink(self, before, node, after):
        """
        helper function used by LinkedList methods
        links `node' between `before' and `after'
        must work correctly if `before' and `after' are the same node
        i.e. they are the sentinel
        """
        node.nextn = after
        node.prevn = before
        after.prevn = node
        before.nextn = node

    def __unlink(self, node):
        """
        helper function used by LinkedList methods
        unlinks node from the doubly linked list
        """
        node.prevn.nextn = node.nextn
        node.nextn.prevn = node.prevn

    def __init__(self):
        self.size = 0
        self.sentinel = LLNode()
        self.sentinel.nextn = self.sentinel
        self.sentinel.prevn = self.sentinel

    def __len__(self):
            return self.size

    def __getitem__(self, index):
        if index >= self.size:
            raise IndexError
        node = self.sentinel.nextn
        for i in range(index):
            node = node.nextn
        return node.data

    def add_last(self, data):
        node = LLNode(data)
        self.__relink(self.sentinel.prevn, node, self.sentinel)
        self.size += 1

    def remove_first(self):
        if self.size <= 0:
            return None
        data = self.sentinel.nextn.data
        self.__unlink(self.sentinel.nextn)
        self.size -= 1
        return data
